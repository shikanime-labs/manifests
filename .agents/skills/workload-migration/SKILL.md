---
name: workload-migration
description: Use when renaming, migrating, or replacing a workload (Deployment or StatefulSet) in this repo.
version: 0.1.0
author: Shikanime Deva, Hermes Agent
license: Apache-2.0
platforms: [linux, macos]
metadata:
  hermes:
    tags: [kubernetes, statefulset, deployment, flux, migration, nishir]
    related_skills: [flux-ks-recovery, overlay-authoring]
---

# Workload Migration

Renames and kind migrations share one failure class: the manifests render and
pass CI, but the rollout bounces off immutable fields, the KS health check
guards a ghost, or an old object lingers forever. Check every gate below.

## The sweep list

A rename/migration touches ALL of these — grep each, in the repo and out:

1. The workload file (`deploy.yaml`/`sts.yaml`) + `svc.yaml` + `netpol.yaml`
   (peer rules select on pod labels).
2. `kustomization.yaml` resources/patches lists (keep sorted).
3. `ks.yaml` — **health-check `kind:` must match the new workload kind**;
   a stale `Deployment` entry after a STS migration makes every reconcile
   time out while pods run healthy (immich case).
4. Pod DNS references: STS pod DNS derives from the STS name — every
   `svc.cluster.local` ref (env vars, cert SANs, peer lists) moves with the
   rename.
5. External refs: `clusters/` ks entries, other apps' netpols/env, and
   fleet repos (machines) pointing at the old name.
6. AGENTS.md nested-example lists if the app appears in one.

## Live-cluster side

- **Delete the orphaned old object** (old-kind Deployment, old-named
  Deployment) after the new one rolls — a stale Deployment referenced by
  nothing is dead weight; a live one serves stale traffic.
- **Immutable STS fields** (`spec.selector`, `spec.serviceName`, VCT names):
  same-name changes are rejected server-side and abort the whole KS apply.
  Kind renames are creates; field changes need STS deletion
  (`--cascade=orphan` when only the volume structure changes) + Flux
  recreate.
- **PVC re-binding by name:** a recreated pod re-attaches the OLD claim if
  it still exists (even Terminating). For cache/disposable data the chain
  is delete STS → delete pods → delete old PVCs (`--wait=false`) → verify
  each mount with `kubectl exec <pod> -- mount | grep <path>` — pod age
  proves nothing, the device name is ground truth.
- **VCT size changes** never resize a reused claim: expand the PVCs online
  first (Retain/Retain policy confirmed), then delete the STS and let Flux
  recreate; claims re-adopt by name.
- **Storage-class / access-mode changes** on bound claims are per-claim PV
  chains (patch PV Retain → assert landed → delete PVC → patch claimRef →
  recreate). `spec.persistentVolumeReclaimPolicy` is the field name —
  `spec.reclaimPolicy` in a patch is silently dropped, no error, and a
  no-op'd Retain flip + PVC delete has destroyed data here. Never skip
  the read-back.
- **Affinity against a label that does not exist yet** = permanent
  FailedScheduling. Defer the affinity and open an issue for the labeling;
  never write it speculatively.

## Render gate

`kustomize build` every touched base + overlay; assert zero references to
dropped names; every container volumeMount resolves to a `volumes:` entry or
VCT name — a dangling mount name blocks scheduling after merge and kustomize
exits 0, so CI never catches it. Overlay VCT patches restate every field
(Kustomize replaces list entries, never field-merges).

Then land via the normal PR flow; after merge, gate on
`flux get kustomization` Ready AND `lastAppliedRevision` = merge SHA, then
re-measure on production.

## Gotchas

- Rename files with plain `mv` in a jj workspace — no `.git`, `git mv`
  fatals.
- Netpol is enforced cross-app: renamed pods lose peer grants that select on
  old labels even though nothing else "references" them.
- Parallel actors land fixes on main mid-migration — `jj git fetch` +
  re-read at `main@origin` + `gh pr list` before opening the PR.
- For HelmRelease/operator-owned workloads, `kustomize build` proves only
  the HR patch; verify at the helm layer (`helm template` coalesced values).
