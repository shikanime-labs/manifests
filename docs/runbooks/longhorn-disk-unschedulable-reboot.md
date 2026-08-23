# Longhorn disk unschedulable → reboot the node

Runbook for a node that has gone `NotReady` (or stopped scheduling volumes)
because Longhorn fenced one of its disks and flipped the node to
`SCHEDULABLE=False`. A reboot re-probes the disk and clears the fenced state
without losing replicas.

## Background

Longhorn fences a disk from scheduling on a transient fault — an I/O error, a
stuck mount, or `storageMinimalAvailablePercentage` pressure — and records the
fence in its in-memory disk state. That flips the node's `Schedulable`
condition to `False`. If the storage plane is unhealthy enough, the kubelet
follows the node to `NotReady`. The fault lives in Longhorn's state, not in a
physically dead drive, so rebooting the node lets the manager re-probe the disk
and drop the fence.

This is a different failure from a dirty XFS log (see
`longhorn-xfs-recovery.md`): that one is a per-volume mount refusal, this one
is a node-wide scheduling block.

## Diagnose

1. Confirm the node is `NotReady` and why:

   ```sh
   kubectl get nodes
   kubectl describe node <node>   # Reason: KubeletNotReady / DiskPressure
   ```

2. Read the Longhorn node condition. A disk fence reports
   `storageScheduled: false`:

   ```sh
   kubectl -n longhorn-system get nodes <node>
   kubectl -n longhorn-system get nodes <node> \
     -o jsonpath='{.status.conditions[?(@.type=="Schedulable")].message}'
   kubectl -n longhorn-system get nodes <node> -o yaml \
     # inspect status.diskStatus.<disk>.conditions
   ```

3. Rule out the cases where a reboot is wrong:
   - **Network partition** — node unreachable, no kubelet heartbeats. Fix the
     link first; a reboot does nothing.
   - **Genuinely failed disk** — the disk reports a hardware error that
     survives a reboot. Rebooting will not help; evacuate the node.
   - Only proceed when the message names an I/O error / mount issue on a disk
     that was healthy before the event.

## Recover

1. Cordon so nothing new lands while it reboots:

   ```sh
   kubectl cordon <node>
   ```

2. Reboot the node (Tailscale SSH / IPMI / BMC). Do **not** `kubectl delete
   node` — that drops the node identity and its Longhorn membership:

   ```sh
   ssh <node> sudo reboot
   # or via BMC, e.g. ipmitool -H <bmc> power cycle
   ```

3. Wait for `Ready` and the Longhorn disk to come back schedulable:

   ```sh
   kubectl wait --for=condition=Ready node/<node> --timeout=300s
   kubectl -n longhorn-system get nodes <node>   # SCHEDULABLE=True
   ```

4. Uncordon:

   ```sh
   kubectl uncordon <node>
   ```

## Verification

```sh
kubectl get nodes <node>                        # STATUS=Ready
kubectl -n longhorn-system get nodes <node>     # SCHEDULABLE=True
kubectl -n longhorn-system get volumes -o wide  # none stuck degraded/unschedulable
```

If `Schedulable` is still `False` after reboot, the disk is genuinely failed —
replace the drive / evacuate the node. Do not loop reboots.

## Prevention

- Reboot nodes gracefully (`systemctl reboot`) so systemd stops RKE2, which
  detaches volumes and unmounts cleanly — fewer disk fences to begin with.
- Replicas on the fenced disk are retained across the reboot; the manager
  re-attaches them on re-probe.
- `kubectl drain` is optional and only safe if the node is still reachable; a
  disconnected node hangs the drain, so cordon + reboot instead.

## References

- Longhorn node `Schedulable` condition and disk conditions:
  https://longhorn.io/docs/
- Sister runbook: `longhorn-xfs-recovery.md` (per-volume dirty-log mount
  failure, not a node-wide fence)
