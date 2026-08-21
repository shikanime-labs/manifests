# Longhorn XFS volume recovery

Runbook for recovering a Longhorn volume whose XFS log was left dirty by an
ungraceful node loss (watchdog hard reset, power cut, kernel panic). The
volume then refuses to mount and the pod using it sticks in
`ContainerCreating` with repeated mount failures.

## Background

Longhorn attaches block devices but never runs a filesystem check on attach.
XFS will not replay a dirty log on its own: when the journal is dirty from an
unmount that never happened, the mount fails until the log is repaired or
zeroed. The fleet formats all volumes XFS, so every volume is exposed to this
after a hard reset of a node holding mounted replicas.

Feature mismatch is NOT the cause here: hosts run recent kernels and the
Longhorn instance-manager image ships its own matching `xfs_repair`, so the
crc/finobt workarounds from upstream KB articles do not apply.

## Diagnose

1. Find the stuck pod and its PVC:

   ```sh
   kubectl get pv <pvc-volume> -o jsonpath='{.spec.csi.volumeHandle}'
   ```

2. Describe the pod events. A dirty-log mount failure shows
   `mount failed: exit status 32` with `log has dirty entries` (or similar)
   in the mount error.
3. Confirm before repairing — attach the device read-only mindset: never run
   repairs against a volume still attached to a workload.

## Recover

Work inside any `longhorn-manager` pod; it carries a matching `xfs_repair`.

1. Scale the affected workload to zero so nothing holds the volume.
2. Detach the volume (UI: detach; or API/`kubectl patch` the volume's
   `.spec.attachedTo` through maintenance mode). Wait for
   `kubectl get volumes.longhorn.io -n longhorn-system` to show the volume
   detached and the engine stopped.
3. Identify the device on the node holding a replica:

   ```sh
   kubectl get nodes.longhorn.io -n longhorn-system \
     -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
   # then locate /host/dev/longhorn/pvc-<handle> on that node's manager pod
   ```

4. Dry-run the repair first — this also confirms the diagnosis:

   ```sh
   kubectl exec -n longhorn-system deploy/longhorn-manager -- \
     xfs_repair -n /host/dev/longhorn/pvc-<handle>
   ```

   Expect `bad magic number` / dirty-log errors confirming the state.

5. Repair without `-L`. This replays or rebuilds the log while preserving
   data and usually completes in seconds:

   ```sh
   kubectl exec -n longhorn-system deploy/longhorn-manager -- \
     xfs_repair -o ag_stride=32 /host/dev/longhorn/pvc-<handle>
   ```

6. Reattach the volume (attach through the UI/API, or just scale the workload
   back up and let Longhorn attach).
7. Verify: the pod starts, and the filesystem mounts cleanly
   (`dmesg` shows XFS recovery, not a second refusal).

## Escalation: `-L` (zero the log)

Only if step 5 fails with a log it cannot repair. `xfs_repair -L` zeroes the
journal; metadata operations that were in flight at crash time are lost and
the filesystem may need phase-two repair afterwards. Treat it as the last
resort before restoring from a Longhorn backup:

```sh
kubectl exec -n longhorn-system deploy/longhorn-manager -- \
  xfs_repair -L /host/dev/longhorn/pvc-<handle>
```

If even `-L` fails, restore: snapshot/backup the broken volume for forensics,
create a replacement PVC, restore the latest healthy backup into it, and
re-point the workload.

## Prevention

- Reboot nodes gracefully whenever possible (`systemctl reboot` lets systemd
  stop RKE2, which detaches volumes and unmounts cleanly).
- Expect dirty logs after any watchdog hard reset; go straight to this
  runbook instead of deleting PVCs.

## References

- Upstream KB: Mount failure with XFS filesystem
  https://longhorn.io/kb/troubleshooting-mount-failure-with-xfs-filesystem/
- Investigation thread: manifests issue tracker, "XFS Longhorn volumes
  require manual xfs_repair -L after node instability"
