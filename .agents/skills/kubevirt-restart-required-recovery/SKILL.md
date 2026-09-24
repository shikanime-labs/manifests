---
name: kubevirt-restart-required-recovery
description: Use when a KubeVirt VM RestartRequired stalls a Flux health check.
version: 0.1.0
author: Shikanime Deva, Hermes Agent
license: Apache-2.0
platforms: [linux, macos]
metadata:
  hermes:
    tags: [kubevirt, flux, health-check, virtualmachine, nishir]
    related_skills: [comin-fleet-deploy]
---

# KubeVirt RestartRequired Stalls Flux Health

A `vm.yaml` edit touching a non-live-updatable field (secret volume, disk,
firmware, machine type) sets the VM condition `RestartRequired=True`. KubeVirt
does not restart a `runStrategy: Always` VM on its own; the VM sits at
`desiredGeneration` > `observedGeneration`, Flux reads that as `InProgress`,
the health check times out (9m30s default), and the Kustomization never
reaches `Ready` — every resource applied `unchanged`. No resource is broken;
this is expected behaviour, not a manifest defect.

## Procedure

1. Confirm the signature: Kustomization `READY=Unknown` + controller log
   `health check failed after 9m30s ... [VirtualMachine/<ns>/<name> status:
   'InProgress']` + VM conditions show `RestartRequired=True` with
   `desiredGeneration` > `observedGeneration` (VMI annotation `vm-generation`
   behind). Generation matching + `Running` → look elsewhere: the VMI is
   actually wedged.
2. Apply the pending restart: `virtctl restart <vm> -n <ns>` (ships in the
   fleet NixOS images). Old VMI → `Succeeded`; new VMI at the applied
   generation; containerDisk pull can take minutes on a cold node.
3. Monitor `printableStatus` / `observedGeneration` / VMI `Ready` until equal
   and `Running`.
4. Re-run the Flux health check: annotate the Kustomization
   `reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite`, then confirm
   `READY=True Healthy=True`.

## Gotchas

- The restart drops the VM's SSH/mDNS for the boot duration — schedule around
  its usage.
- `LiveMigratable=False` is expected and unrelated: the workspaces PVC is
  `ReadWriteOncePod`, live migration is impossible by design.
- Plan the `virtctl restart` inside the same change window as any
  non-live-updatable VM edit, or Flux sits at `Unknown` in between.

## Alternative

If VM readiness is not needed as a deploy gate, remove the
`VirtualMachine/<name>` entry from `healthChecks` in the owning Kustomization
(e.g. `clusters/nishir/overlays/tailnet/ks.yaml`, `apps-catbox`). Deliberate
trade-off: the gate exists to surface this drift — document it in the PR.

## Verification

`flux get kustomization <ks> -n flux-system` → `READY=True Healthy=True`;
VM `observedGeneration == desiredGeneration`, `RestartRequired` gone.
