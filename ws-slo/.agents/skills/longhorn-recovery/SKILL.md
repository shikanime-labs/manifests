---
name: longhorn-recovery
description: Use when any Longhorn volume or node storage fails on the fleet.
version: 0.1.0
author: Shikanime Deva, Hermes Agent
license: Apache-2.0
platforms: [linux, macos]
metadata:
  hermes:
    tags: [kubernetes, longhorn, xfs, storage, recovery, nishir]
    related_skills: [k8s-node-offline-diagnosis, k8s-volume-expansion]
---

# Longhorn Recovery

Three distinct failure modes share this skill. Triage first — the recovery
levers differ and the wrong one destroys access or the API server.

## Triage

| Symptom                               | Mode            |
| ------------------------------------- | --------------- |
| Pod `ContainerCreating`, mount exit 32 | dirty XFS log   |
| + share-manager pod crash-looping     | dirty XFS (RWX) |
| Node `NotReady` / `SCHEDULABLE=False` | disk fence      |

- dirty XFS log → `references/xfs-recovery.md`
- dirty XFS (RWX) → `references/rwx-xfs-recovery.md`
- disk fence → `references/disk-unschedulable-reboot.md`

Decision rule: the failure is per-volume (mount refusal) → XFS recovery;
node-wide (scheduling block) → disk-fence reboot. A bare `exit status 32` with
a healthy share-manager pod is NOT XFS — see Gotchas before escalating.

## Procedure

1. Run the triage table against live symptoms (`kubectl get pods -A | grep -E
   'ContainerCreating|Init'`, `kubectl -n longhorn-system get nodes`).
2. Load exactly one reference, follow it end to end.
3. Verify per that reference's final section; report any gate that fails.

## Gotchas

- Never cordon nodes to pin a volume — it broke the API server on this fleet.
  Pin via `.spec.nodeID` after the RWX→RWOP flip, never cordons.
- `xfs_repair -n` exiting **1** with "Maximum metadata LSN ... ahead of log"
  means a plain repair works; only `EXIT=2` justifies `-L`.
- Repair inside a `longhorn-manager` pod (it ships matching `xfs_repair`);
  absolute kubectl path in any backgrounded exec (host PATH is lost, exit 127).
- `Scheduled=False` / `tags not fulfilled` after repair is a storage-topology
  gap (missing disk tag, e.g. `nearline`) — fix the tag in GitOps, never drop
  replica count to hide it.
- `kubectl delete node` on a fenced node drops its Longhorn membership —
  reboot instead, and never loop reboots on a disk that stays fenced.

## Verification

- XFS: consumer pod `Running`, share-manager `Ready=True`, volume
  `robustness=healthy`.
- Disk fence: node `Ready`, Longhorn node `SCHEDULABLE=True`, no volume stuck
  degraded.
