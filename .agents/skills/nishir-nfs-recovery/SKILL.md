---
name: nishir-nfs-recovery
description: Use when pods fail mounts to a Longhorn NFS share (stale IP).
version: 0.1.0
author: Shikanime Deva, Hermes Agent
license: Apache-2.0
platforms: [linux, macos]
metadata:
  hermes:
    tags: [kubernetes, nfs, longhorn, kubelet, recovery, nishir]
    related_skills: [longhorn-recovery]
---

# NFS Share-Manager Recovery (nishir)

Pods stuck in `ContainerCreating`/`Init` on a Longhorn volume served over NFS:
`FailedMount ... attacher.MountDevice ... DeadlineExceeded`, kubelet repeating
`unmounted volumes=[<vol>]` every 30 s, and CSI plugin logs silent (no
`NodeStageVolume` at all — the kubelet never invoked the plugin).

Root cause: the share-manager pod restarted, its Service got a new ClusterIP,
and stale mounts on the consumer node point at the old IP. Optionally layered
on top: a deleted pod's subpath cleanup wedge in kubelet's
`nestedpendingoperations` queue.

## Triage gate

Only apply when the share-manager pod itself is `Running`. If it is in
`starting`/`Failed` with `Failed to recover intents`, that is dirty-XFS
territory — load the `longhorn-recovery` skill instead. Do not jump there on a
bare `exit status 32`: on nishir one such exit came from the NPO wedge alone
and cleared after the kubelet restart.

## Procedure

SSH as **root** — `ssh root@<consumer-node>.taila659a.ts.net` (bare hostname
denied by tailnet policy; the `nishir` user lacks passwordless sudo).

1. Verify before acting: ShareManager CR `.status.endpoint` (authoritative even
   when `volume.status.endpoint` is empty), share-manager pod health, a dry
   NFSv4.1 mount test from the consumer node, and a kubelet.log grep for the
   NPO wedge. Stale mounts show an old ClusterIP in `mount` output.
2. Lazy-unmount every stale mount on the consumer node: `umount -l
   <old-cluster-ip>:/<vol>`. Leave dead-pod subpath dirs for kubelet GC.
3. Restart kubelet via `systemctl restart rke2-server` (RKE2 supervisor owns
   kubelet; never kill the kubelet process directly). Quorum note: safe on a
   control-plane node with ≥3 control-plane nodes.
4. Recreate the stuck pods (`kubectl -n <ns> delete pod <pod>`) — creating in
   place does NOT clear the wedge.
5. Verify: pod `1/1 Running`, `mount` shows the current ClusterIP, the dry
   mount test lists data.

The restart clears every wedged volume on the node at once — after it, sweep
ALL pods on the node, not just the reported one.

## Gotchas

- Do not rebuild/reinstall ganesha.nfsd on any host — the share-manager pod IS
  the NFS server (a stray host ganesha on manash was a red herring).
- Do not patch `/etc/exports` or `/tmp/vfs.conf`, do not force-delete the
  Longhorn volume.
- Why CSI is silent: after a failed subpath cleanup (`device is busy`), kubelet
  marks the operation permanently failed and queues later mount attempts after
  the dead entry — they never reach the plugin. The restart clears the whole
  NPO queue.

## Verification

Consumer pod `Running`; active mount points at the ShareManager endpoint IP;
`mount -t nfs4 -o vers=4.1,... <ip>:<vol> /tmp/t && ls /tmp/t` succeeds.
