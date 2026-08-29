# Longhorn RWX volume XFS recovery

Generic runbook for recovering a Longhorn **RWX (ReadWriteMany)** volume whose
XFS log was left dirty by an ungraceful node loss. RWX volumes add a
chicken-and-egg the plain (RWO) case does not have: the `ShareManager` CR owns
an NFS export pod that needs a clean mount, while the dirty log blocks that
mount — and that pod's existence holds/migrates the engine so the raw device
cannot be repaired. The fix is to flip the volume to **RWO** (which
deletes the ShareManager CR and exposes the block device), repair, then flip
back to RWX.

The general procedure and `-L` escalation live in `longhorn-xfs-recovery.md`.
This file is the copy-paste RWX playbook. Replace the `ENV` placeholders with
the values for the volume you are repairing; a real worked example is appended
at the end.

## Environment (set before each step)

```sh
KB=/nix/store/<hash>-kubectl-<ver>/bin/kubectl  # absolute path to kubectl
VOL=<volume-name>                    # Longhorn volume (== PVC volumeName)
NS=longhorn-system
MGR_POD=<longhorn-manager-xxxxx>  # node currently holding the engine
NODE=<node>                                    # node you will pin the engine to
DEV=/host/dev/longhorn/$VOL
# consumer StatefulSets (namespaces may vary):
CONSUMER_NS=<namespace>                         # e.g. shikanime
CONSUMERS="<sts-a> <sts-b> <sts-c>"            # StatefulSets mounting $VOL
DESIRED_REPLICAS=<n>  # intended replicas (e.g. 2)
```

> Select the cluster context first (e.g. `kubectl config use-context
> <CLUSTER_CONTEXT>`). `kubectl` inside a cluster `exec`/background context
> needs the **absolute path** — the manager container's PATH is not what your
> shell has, and a background `kubectl exec` started from the host loses the
> host PATH (exit 127). Use `$KB` above, not bare `kubectl`, in any script that
> runs in a subshell. Find the path with `which kubectl` (or on the host
> `ls /nix/store/*-kubectl-*/bin/kubectl`).

## Consumers

Identify every workload mounting `$VOL` (StatefulSets/Deployments in
`$CONSUMER_NS`). Scale these to 0 before repairing and back to their original
replicas after. Flux will reconcile them anyway, but an explicit scale-down
guarantees nothing holds the volume.

```sh
$KB -n $CONSUMER_NS scale sts $CONSUMERS --replicas=0
$KB -n $CONSUMER_NS get pods -l app.kubernetes.io/name=<one-consumer>   # gone
```

## Procedure

### 1. Snapshot first (safety net)

```sh
$KB -n $NS create snapshot $VOL-prerepair-$(date +%Y%m%d-%H%M%S) \
  --type snap --label intent=pre-xfs-repair
```

### 2. Flip RWX → RWO (kills ShareManager, exposes the block device)

```sh
$KB -n $NS patch volume $VOL --type=merge \
  -p '{"spec":{"accessMode":"rwo","nodeID":""}}'
```

Wait for the `ShareManager` CR and `share-manager-$VOL` pod to disappear:

```sh
$KB -n $NS get sharemanager $VOL 2>&1   # should be NotFound
$KB -n $NS get pod share-manager-$VOL 2>&1
```

### 3. Pin the engine to a known node and confirm the device is present + unmounted

```sh
$KB -n $NS patch volume $VOL --type=merge -p '{"spec":{"nodeID":"'$NODE'"}}'
$KB -n $NS get volume $VOL -o jsonpath='state={.status.state} node={.status.currentNodeID}{"\n"}'
# device should now exist on that node's manager pod:
$KB -n $NS exec $MGR_POD -c longhorn-manager -- \
  sh -c "ls -la $DEV; mount | grep $(basename $DEV) || echo UNMOUNTED"
# resolve MGR_POD to the actual manager pod on the now-pinned node:
MGR_POD=$($KB -n $NS get pod -l app=longhorn-manager \
  -o jsonpath="{.items[?(@.spec.nodeName==\"$NODE\")].metadata.name}")
echo "MGR_POD=$MGR_POD"
```

Confirm `state=attached`, the device node exists (e.g. `brw-rw---- ... 8, 112`),
and it is NOT mounted. If the device is missing, wait — the attach is async —
and re-check.

### 4. Dry-run the repair (confirms diagnosis, shows whether `-L` is needed)

```sh
$KB -n $NS exec $MGR_POD -c longhorn-manager -- \
  sh -c "xfs_repair -n $DEV; echo XFS_N_EXIT=\$?"
```

For a plain dirty-log (metadata intact) you will see:

```text
Maximum metadata LSN (68:1566) is ahead of log (1:2).
Would format log to cycle 71.
No modify flag set, skipping filesystem flush and exiting.
```

and **`XFS_N_EXIT=1`** (not 2). That means a plain `xfs_repair` (no `-L`)
repairs it. `-L` is only for `EXIT=2` / unrecoverable-log cases.

### 5. Run the real repair (no `-L`)

```sh
$KB -n $NS exec $MGR_POD -c longhorn-manager -- \
  sh -c "xfs_repair $DEV; echo XFS_EXIT=\$?"
```

This is long on large volumes (1Ti). Run it in the background and watch the
device:

```sh
# background: the exec holds the device open until done
$KB -n $NS exec $MGR_POD -c longhorn-manager -- \
  sh -c "xfs_repair $DEV; echo XFS_EXIT=\$?" > /tmp/fix-$VOL.log 2>&1 &

# in another shell, the device is "busy" until repair finishes; wait for free:
REPAIRED=0
for i in $(seq 1 72); do
  if $KB -n $NS exec $MGR_POD -c longhorn-manager -- \
    sh -c "xfs_repair -n $DEV" >/dev/null 2>&1; then
    REPAIRED=1; break
  fi
  sleep 10
done
[ "$REPAIRED" = 1 ] || { echo "repair not clean after waiting; abort"; exit 1; }
```

A successful repair prints `XFS_EXIT=0` (or the post-check shows `NEXIT=0`):

```text
Phase 7 - verify link counts...
No modify flag set, skipping filesystem flush and exiting.
NEXIT=0
```

### 6. Re-enable RWX

```sh
$KB -n $NS patch volume $VOL --type=merge -p '{"spec":{"accessMode":"rwx"}}'
```

The `ShareManager` CR and `share-manager-$VOL` pod are recreated automatically.

### 7. Restore replicas to the desired count

```sh
$KB -n $NS patch volume $VOL --type=merge -p '{"spec":{"numberOfReplicas":'$DESIRED_REPLICAS'}}'
```

> **Note:** the second replica only schedules if a disk carries the volume's
> `diskSelector` tag. If **no disk is tagged** with that tag the volume stays
> `degraded` with `Scheduled=False` / reason
> `precheck new replica failed: insufficient storage; tags not fulfilled`. That
> is a storage-topology gap, not a filesystem defect — fix the disk tags in
> GitOps (e.g. `configs/longhorn/overlays/<cluster>/storageclass.yaml`), not
> the repair. See `longhorn-xfs-recovery.md` §"Replica count and the
> `diskSelector` trap".

### 8. Verify

```sh
$KB -n $NS get pod share-manager-$VOL -o jsonpath='ready={.status.conditions[?(@.type=="Ready")].status}{"\n"}'
$KB -n $NS get volume $VOL -o jsonpath='accessMode={.spec.accessMode}{"\n"}'
$KB -n $NS get volume $VOL -o jsonpath='robustness={.status.robustness}{"\n"}'
$KB -n $NS get volume $VOL -o jsonpath='state={.status.state}{"\n"}'
# scale consumers back
$KB -n $CONSUMER_NS scale sts $CONSUMERS --replicas=1
$KB -n $CONSUMER_NS get pods -l app.kubernetes.io/name=<one-consumer>
# Running + mounted
```

Success: SM pod `Ready=True`, NFS-Ganesha logs `NFS SERVER INITIALIZED`, volume
`robustness=healthy` (after the second replica finishes syncing), consumers
`Running`.

## Failure modes observed (do NOT repeat)

| Attempt | What we tried                                               | Why it failed                                                                                                                                                                             |
| ------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1       | `spec.nodeID` pin only                                      | The field is cleared/overridden after attach; engine migrated off the pinned node anyway.                                                                                                 |
| 2       | `allowScheduling=false` on the non-engine Longhorn Node CRs | Does **not** stop the share-manager pod — that is a regular k8s pod scheduled by the SM controller, not the Longhorn replica scheduler.                                                   |
| 3       | `spec.disableFrontend: true` (+ nodeID)                     | Fully **detached** the volume (device vanished). Wrong lever unless in maintenance mode.                                                                                                  |
| 4       | Delete the `ShareManager` CR alone (volume still RWX)       | The Volume owns the ShareManager CR; the controller recreated it.                                                                                                                         |
| 5       | Delete SM pod once + immediate repair                       | Worked in the reference case, but a 1Ti repair outlasts the ~2-min SM recreate window; the pod respawned and dragged the engine to a new node mid-repair (`EXIT=134` / `No such device`). |
| 6       | Launch repair before the device re-attached                 | `fatal error -- couldn't initialize XFS library` (device wasn't present yet).                                                                                                             |
| 7       | Cordon 5/6 nodes to "pin" the volume                        | Broke the API server (`dial tcp <api>:443: i/o timeout`). **Never cordon to pin a volume.** Uncordon immediately.                                                                          |

The only reliable path was: **snapshot → RWX→RWO flip → pin node → confirm
device present & unmounted → `xfs_repair` (no `-L`) → re-enable RWX → set
replicas**. No cordons, no `disableFrontend`, no lone CR delete.

## References

- Sister runbook: `longhorn-xfs-recovery.md` (general procedure + `-L`
  escalation + `diskSelector` trap)
- `longhorn-disk-unschedulable-reboot.md` (node-wide fence, not a per-volume
  mount refusal)
- Longhorn KB: Mount failure with XFS filesystem
  <https://longhorn.io/kb/troubleshooting-mount-failure-with-xfs-filesystem/>
- Longhorn issue #2338 (RWX block device not exposed without accessMode flip)
- Longhorn discussion #4682 (ShareManager gRPC server not running on dirty log)

---

## Worked example: volume `sukebe-doujins-data` (nishir)

Concrete values from a real incident on cluster `nishir`. The volume is a 1Ti
XFS **RWX** volume in namespace `shikanime`, consumed by three StatefulSets
(`copyparty`, `jellyfin`, `syncthing`), exposed over NFS through the
share-manager. It hit a dirty-XFS-log failure after a node instability event
and stuck in `degraded`.

```sh
# kubectl is the absolute path on the operator host — use it directly:
/nix/store/f2dn3sm4xhh3f44gni94dwqascvd7y1s-kubectl-1.36.3/bin/kubectl \
  -n longhorn-system get volume sukebe-doujins-data
# consumers quiesced before repair:
/nix/store/f2dn3sm4xhh3f44gni94dwqascvd7y1s-kubectl-1.36.3/bin/kubectl \
  -n shikanime scale sts copyparty jellyfin syncthing --replicas=0
# engine pinned to ashira (sukebe-doujins-data is a 1Ti RWX volume):
/nix/store/f2dn3sm4xhh3f44gni94dwqascvd7y1s-kubectl-1.36.3/bin/kubectl \
  -n longhorn-system patch volume sukebe-doujins-data --type=merge \
  -p '{"spec":{"nodeID":"ashira"}}'
# manager pod on the pinned node (resolved per §3): longhorn-manager-8cvrp
/nix/store/f2dn3sm4xhh3f44gni94dwqascvd7y1s-kubectl-1.36.3/bin/kubectl \
  -n longhorn-system exec longhorn-manager-8cvrp -c longhorn-manager -- \
  sh -c "xfs_repair -n /host/dev/longhorn/sukebe-doujins-data"
# after clean repair, re-enable RWX and restore 2 replicas:
/nix/store/f2dn3sm4xhh3f44gni94dwqascvd7y1s-kubectl-1.36.3/bin/kubectl \
  -n longhorn-system patch volume sukebe-doujins-data --type=merge \
  -p '{"spec":{"accessMode":"rwx","numberOfReplicas":2}}'
# bring consumers back:
/nix/store/f2dn3sm4xhh3f44gni94dwqascvd7y1s-kubectl-1.36.3/bin/kubectl \
  -n shikanime scale sts copyparty jellyfin syncthing --replicas=1
```

Note on replicas: `sukebe-doujins-data` uses storageClass `nishir-transient`
whose `diskSelector: nearline`. At incident time **no disk was tagged
`nearline`**, so the volume stayed `degraded` with `Scheduled=False` /
`precheck new replica failed: insufficient storage; tags not fulfilled` even
after a clean repair. The filesystem was healthy; the residual gap was a
storage-topology fix (add the `nearline` tag to the intended disks in
`configs/longhorn/overlays/nishir/storageclass.yaml`), not a repair defect.
