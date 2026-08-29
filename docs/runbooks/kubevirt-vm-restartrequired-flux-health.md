# KubeVirt VM RestartRequired stalls Flux health check

Runbook for when a KubeVirt `VirtualMachine` carries a pending restart that
Flux's `healthChecks` treats as an `InProgress` object, leaving the
Kustomization `READY=Unknown` / `Healthy=Unknown` even though every resource
applied `unchanged`. First observed on `apps-catbox` (`VirtualMachine/catbox`)
in the `nishir` cluster.

## Background

Flux's `kustomize-controller` runs the `healthChecks` listed on a
Kustomization after server-side apply. For a `VirtualMachine`, the check passes
only when the VM reports a healthy `printableStatus` (e.g. `Running`) and
`observedGeneration` equals `desiredGeneration`.

A `vm.yaml` edit that touches a non-live-updatable field — a secret volume, a
disk, firmware, machine type — makes KubeVirt set the VM condition
`RestartRequired=True`. KubeVirt wants to recreate the `VirtualMachineInstance`
to apply the change, but it does not do so on its own for a `runStrategy: Always`
VM that is already running; the existing VMI stays at the old generation. The VM
then sits at `desiredGeneration` > `observedGeneration` with `RestartRequired`
still `True`.

Flux samples the VM during its health-check window and reads that
generation-mismatch state as `InProgress`, so the check times out (default
9m30s) and the Kustomization never reaches `Ready`. No resource is actually
broken — the live object is simply behind the already-applied generation.

This is the expected behaviour whenever such a field changes. It is not a
manifest defect.

## Diagnose

1. The Kustomization is stuck:

   ```sh
   flux get kustomization apps-catbox -n flux-system
   # READY=Unknown  Healthy=Unknown  "Reconciliation in progress"
   ```

2. The controller logs show the health-check timeout on the VM:

   ```sh
   kubectl logs -n flux-system -l app=kustomize-controller --since=30m \
     | grep -iE "catbox|health"
   # health check failed after 9m30s: timeout waiting for:
   #   [VirtualMachine/shikanime/catbox status: 'InProgress']
   ```

3. The VM itself looks healthy but is generation-mismatched:

   ```sh
   kubectl get vm catbox -n shikanime -o wide
   # STATUS Running, READY True
   kubectl get vm catbox -n shikanime \
     -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{" ("}{.message}{")\n"}{end}'
   # RestartRequired=True (a non-live-updatable field was changed in the
   #   template spec)
   kubectl get vm catbox -n shikanime \
     -o jsonpath='{desiredGen="}{.status.desiredGeneration}{" obsGen="}{.status.observedGeneration}{"\n"}'
   # desiredGen=28 obsGen=27   <-- mismatch = the stall
   ```

4. Confirm the VMI is the old generation (still running the previous spec):

   ```sh
   kubectl get vmi catbox -n shikanime \
     -o jsonpath='{vmGen="}{.metadata.annotations.kubevirt\.io/vm-generation}{"\n"}'
   # vmGen=27  <-- behind the VM's desiredGeneration 28
   ```

If `desiredGeneration` > `observedGeneration` with `RestartRequired=True`, this
runbook applies. If the generation matches and the VM is `Running`, look
elsewhere (the VMI is actually wedged, not merely pending a restart).

## Recover

Apply the pending restart so the VM realizes its applied generation. `virtctl`
ships in the fleet NixOS images.

```sh
virtctl restart catbox -n shikanime
# VM catbox was scheduled to restart
```

What happens:

1. The old VMI enters `Succeeded` and its launcher pod terminates.
2. KubeVirt recreates the VMI at the new generation (`vm-generation` annotation
   advances to match `desiredGeneration`).
3. The launcher pod pulls the `catbox:latest` containerDisk image (can take
   several minutes on a cold node) and the guest boots.
4. The VMI reaches `Ready=True` and the VM `printableStatus` returns to
   `Running` with `observedGeneration == desiredGeneration`.

Monitor until healthy:

```sh
for i in $(seq 1 60); do
  kubectl get vm catbox -n shikanime \
    -o jsonpath='{printable="}{.status.printableStatus}{" gen="}{.status.observedGeneration}{"/"}{.status.desiredGeneration}{"\n"}'
  kubectl get vmi catbox -n shikanime \
    -o jsonpath='{ready="}{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
  sleep 10
done
```

Then force Flux to re-run the health check:

```sh
kubectl annotate kustomization apps-catbox -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
flux get kustomization apps-catbox -n flux-system
# READY=True  Healthy=True  "Health check passed"
```

The restart drops catbox's SSH (22/TCP) and mDNS (5353/UDP) for the boot
duration (~30s to a few minutes depending on image pull). Schedule around
catbox's usage.

## Prevention

- A restart is required after any non-live-updatable `vm.yaml` change. If the
  VM will not be used immediately, plan the `virtctl restart` as part of the
  same change window so Flux does not sit at `Unknown` for the whole interval.
- `LiveMigratable=False` is expected and unrelated: the workspaces PVC is
  `ReadWriteOncePod`, so live migration is impossible by design. It does not
  cause this stall.

## Alternative: drop the health gate

If the `InProgress` stall is undesirable and the VM's readiness is not needed as
a deploy gate, remove the `VirtualMachine/catbox` entry from
`healthChecks` in `clusters/nishir/overlays/tailnet/ks.yaml`. Flux then checks
only that objects applied, not that the VM recreated. Do this deliberately —
the gate exists to surface exactly this drift — and document the trade-off in
the PR.

## References

- Flux `healthChecks` on `VirtualMachine/catbox`:
  `clusters/nishir/overlays/tailnet/ks.yaml` (`apps-catbox` Kustomization)
- KubeVirt `RestartRequired` condition on `VirtualMachine`
- Sister runbook: `longhorn-xfs-recovery.md` (separate storage-volume failure
  mode, not related to this VM-generation stall)
