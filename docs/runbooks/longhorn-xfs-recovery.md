# Longhorn XFS volume recovery

Runbook for recovering a Longhorn volume whose XFS log was left dirty by an
ungraceful node loss (watchdog hard reset, power cut, kernel panic). The volume
then refuses to mount and the pod using it sticks in `ContainerCreating` with
repeated mount failures.

The RWX (ReadWriteMany) variant is the hard case — it has a chicken-and-egg
between the NFS share-manager pod and the raw-device repair. A copy-paste
RWX playbook with parameterised steps is in `longhorn-rwx-xfs-recovery.md`.

## Background

Longhorn attaches block devices but never runs a filesystem check on attach. XFS
will not replay a dirty log on its own: when the journal is dirty from an
unmount that never happened, the mount fails until the log is repaired or
zeroed. The fleet formats all volumes XFS, so every volume is exposed to this
after a hard reset of a node holding mounted replicas.

Feature mismatch is NOT the cause here: hosts run recent kernels and the
Longhorn instance-manager image ships its own matching `xfs_repair`, so the
crc/finobt workarounds from upstream KB articles do not apply.

### Why RWX is special

An RWX volume owns a `ShareManager` CR (`longhorn.io/v1beta2`, created and owned
by the Volume). The ShareManager controller spawns a `share-manager-<vol>` pod
that mounts the XFS filesystem and exports it over NFS. The dirty log blocks
that mount (`share manager gRPC server is not running`), but the pod's existence
**holds and migrates the engine**, so you cannot repair the raw
`/host/dev/longhorn/<vol>` device underneath it.

For RWX, **the block device is not exposed while the ShareManager exists.** You
must flip the volume to RWO:

- `kubectl patch volume <vol> --type=merge -p '{"spec":{"accessMode":"rwo","nodeID":""}}'`

That deletes the `ShareManager` CR and its pod and exposes
`/host/dev/longhorn/<vol>` as a block device you can `xfs_repair`. After repair,
flip back to `rwx` and the ShareManager is recreated automatically. (Longhorn
issue #2338 — `attach without frontend` / maintenance mode does NOT create the
blockdev for an RWX volume; the `accessMode` flip is the required extra step.)

## Diagnose

1. Find the stuck pod and its PVC volume handle:

   ```sh
   kubectl get pv <pvc-volume> -o jsonpath='{.spec.csi.volumeHandle}'
   ```

2. Describe the pod events. A dirty-log mount failure shows
   `mount failed: exit status 32` with `log has dirty entries` (or similar) in
   the mount error.
3. If the volume is RWX, confirm the share-manager stall rather than a plain
   mount error:

   ```sh
   kubectl -n longhorn-system logs share-manager-<vol> --tail=20
   # look for: "share manager gRPC server is not running" / mount of XFS failing
   kubectl -n longhorn-system get sharemanager <vol>   # exists, but pod never Ready
   ```

4. Confirm before repairing — never run repairs against a volume still attached
   to a live workload.

## Recover (RWO volume)

Work inside any `longhorn-manager` pod; it carries a matching `xfs_repair`.

1. Scale the affected workload to zero so nothing holds the volume.
2. Detach the volume (UI: detach; or patch the volume's `.spec.attachedTo`
   through maintenance mode). Wait for
   `kubectl get volumes.longhorn.io -n longhorn-system` to show the volume
   detached and the engine stopped.
3. Identify the device on the node holding a replica:

   ```sh
   kubectl get nodes.longhorn.io -n longhorn-system \
     -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
   # then locate /host/dev/longhorn/<vol> on that node's manager pod
   ```

4. Dry-run the repair first — this also confirms the diagnosis:

   ```sh
   kubectl exec -n longhorn-system deploy/longhorn-manager -- \
     xfs_repair -n /host/dev/longhorn/<vol>
   ```

   Expect dirty-log errors. A **plain dirty log with intact metadata** prints:

   ```text
   Maximum metadata LSN (68:1566) is ahead of log (1:2).
   Would format log to cycle 71.
   No modify flag set, skipping filesystem flush and exiting.
   ```

   and exits **1**, **not 2**. That means a plain `xfs_repair` (no `-L`) repairs
   it — see step 5. `EXIT=2` (unrecoverable log) means you need `-L`.
5. Repair without `-L`. This replays or rebuilds the log while preserving data:

   ```sh
   kubectl exec -n longhorn-system deploy/longhorn-manager -- \
     xfs_repair /host/dev/longhorn/<vol>
   ```

   `xfs_repair` is long on large volumes (1Ti can take minutes). Run it in the
   background and confirm completion by re-running the dry-run — the device
   reports `Device or resource busy` until the repair finishes:

   ```sh
   kubectl exec -n longhorn-system deploy/longhorn-manager -- \
     xfs_repair -n /host/dev/longhorn/<vol>   # NEXIT=0 once clean
   ```

6. Reattach the volume (attach through the UI/API, or just scale the workload
   back up and let Longhorn attach).
7. Verify: the pod starts, and the filesystem mounts cleanly (`dmesg` shows XFS
   recovery, not a second refusal).

## Recover (RWX volume) — the reliable path

1. **Snapshot first** (safety net):

   ```sh
   kubectl -n longhorn-system create snapshot \
     <vol>-prerepair-$(date +%Y%m%d-%H%M%S) \
     --type snap --label intent=pre-xfs-repair
   ```

2. **Flip RWX → RWO** (deletes ShareManager CR + pod, exposes the block device):

   ```sh
   kubectl -n longhorn-system patch volume <vol> --type=merge \
     -p '{"spec":{"accessMode":"rwo","nodeID":""}}'
   ```

   Wait for `sharemanager/<vol>` and `pod/share-manager-<vol>` to disappear.
3. **Pin the engine** to a known node and confirm the device is present and
   **NOT mounted**:

   ```sh
   kubectl -n longhorn-system patch volume <vol> --type=merge \
     -p '{"spec":{"nodeID":"<node>"}}'
   kubectl -n longhorn-system exec <mgr-pod> -c longhorn-manager -- \
     sh -c "ls -la /host/dev/longhorn/<vol>; mount | grep <vol> || echo UNMOUNTED"
   ```

4. **Dry-run** (step 4 above) to confirm `EXIT=1` (no `-L` needed).
5. **Repair** (step 5 above) — no `-L`.
6. **Re-enable RWX** (recreates ShareManager automatically):

   ```sh
   kubectl -n longhorn-system patch volume <vol> --type=merge \
     -p '{"spec":{"accessMode":"rwx"}}'
   ```

7. **Restore the desired replica count** (see below re: the `diskSelector`
   trap).
8. **Verify** the share-manager pod reaches `Ready` and NFS-Ganesha logs
   `NFS SERVER INITIALIZED`.

## Replica count and the `diskSelector` trap

After repair you usually restore `spec.numberOfReplicas` to the volume's
intended value (most fleet volumes: 2). The new replica will only schedule if a
disk satisfies the volume's `diskSelector`. For example `nishir-transient`
(`configs/longhorn/overlays/nishir/storageclass.yaml`) sets
`diskSelector: nearline`.

If **no disk is tagged `nearline`**, the volume stays `degraded` with:

```text
Scheduled=False  reason: ReplicaSchedulingFailure
message: precheck new replica failed: insufficient storage; tags not fulfilled
```

That is a **storage-topology gap, not a filesystem defect** — fix the disk tags
in GitOps (tag the intended nearline disks), do not drop the replica count to
hide it. Use `Scheduled=False` as the tell:

```sh
kubectl -n longhorn-system get volume <vol> -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{"\n"}{end}'
```

## Things that do NOT work (do not repeat)

- **Cordoning nodes to pin a volume.** In this cluster, cordoning 5/6 nodes
  broke the API server (`dial tcp 100.121.211.56:443: i/o timeout`). Never
  cordon to pin a volume — if the engine migrates, fix it via `.spec.nodeID`
  (after the RWX→RWO flip), not node cordons.
- **`spec.nodeID` pin alone** (RWX). The field is cleared/overridden after
  attach; the engine migrates anyway. Pin only works once the ShareManager is
  gone (post-RWO-flip).
- **`allowScheduling=false` on Longhorn Node CRs.** Does not stop the
  share-manager pod — it is a regular k8s pod scheduled by the SM controller,
  not the Longhorn replica scheduler.
- **`spec.disableFrontend: true`.** Fully detaches the volume (device vanishes).
  Wrong lever unless in maintenance mode.
- **Deleting the `ShareManager` CR alone** (volume still RWX). The Volume owns
  the CR; the controller recreates it.
- **Delete SM pod + immediate repair** on a large volume. A 1Ti repair outlasts
  the ~2-min SM recreate window; the pod respawns and drags the engine to a new
  node mid-repair (`EXIT=134` / `No such device`).
- **Repair before the device re-attaches.**
  `fatal error -- couldn't initialize XFS library` because the device wasn't
  present yet.

Background exec note: a `kubectl exec` of `xfs_repair` in a subshell from the
host loses the host PATH (exit 127). Use the absolute kubectl path (e.g.
`/nix/store/<hash>-kubectl-<ver>/bin/kubectl`) in any scripted/background run.

## Escalation: `-L` (zero the log)

Only if the plain `xfs_repair` fails with a log it cannot repair (`EXIT=2`).
`xfs_repair -L` zeroes the journal; metadata operations that were in flight at
crash time are lost and the filesystem may need a phase-two repair afterwards.
Treat it as the last resort before restoring from a Longhorn backup:

```sh
kubectl exec -n longhorn-system deploy/longhorn-manager -- \
  xfs_repair -L /host/dev/longhorn/<vol>
```

If even `-L` fails, restore: snapshot/backup the broken volume for forensics,
create a replacement PVC, restore the latest healthy backup into it, and
re-point the workload.

## Prevention

- Reboot nodes gracefully whenever possible (`systemctl reboot` lets systemd
  stop RKE2, which detaches volumes and unmounts cleanly).
- Expect dirty logs after any watchdog hard reset; go straight to this runbook
  instead of deleting PVCs.
- For RWX volumes, document the RWX→RWO→repair→RWX dance up front so the
  ShareManager chicken-and-egg does not burn an operator's afternoon.

## References

- Upstream KB: Mount failure with XFS filesystem
  <https://longhorn.io/kb/troubleshooting-mount-failure-with-xfs-filesystem/>
- Longhorn issue #2338 (RWX block device not exposed without accessMode flip)
- Longhorn discussion #4682 (ShareManager gRPC server not running on dirty log)
- RWX copy-paste playbook: `longhorn-rwx-xfs-recovery.md`
- Sister runbook: `longhorn-disk-unschedulable-reboot.md` (node-wide fence, not
  a per-volume mount refusal)
