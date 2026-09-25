---
name: vpa-memory-floor-audit
description: Use when sizing VPA minAllowed memory floors fleet-wide.
version: 0.1.0
author: Shikanime Deva, Hermes Agent
license: Apache-2.0
platforms: [linux, macos]
metadata:
  hermes:
    tags: [kubernetes, vpa, memory, oom, audit, nishir]
    related_skills: [vpa-resource-audit]
---

# VPA minAllowed Memory Floor Audit

A workload crashloops under node memory pressure with no container OOMKilled
event: the VPA InPlace recommender let its request drift below the real
working set after recommender history reset. This skill is the generic recipe
for a fleet-wide `minAllowed` audit.

Scope: **memory only**. CPU floors fight throttling, not eviction; storage is
PVC territory (`allowVolumeExpansion`). If the symptom is CPU or disk, this is
the wrong skill.

## Procedure

1. **Scan** every VPA in one JSON dump (no pipes; one script). Compare
   `status.recommendation.containerRecommendations[].lowerBound.memory`
   against `spec.resourcePolicy.containerPolicies[].minAllowed.memory` per
   container. Flag: no floor with lowerBound ≥ 300Mi, or a floor more than
   1.5× below the lower bound. Revisit the 300Mi threshold only if node sizes
   change.
2. **Resolve pods by owner**, never by name guess (VPA name ≠ pod name) —
   join on namespace + container name or ownerReferences.
3. **Gather kill evidence** (restartCount + `lastState.terminated.reason` per
   container) and give one of three verdicts:
   - **Floor** — recent `OOMKilled` or working set tracking the lowerBound.
     Set `minAllowed.memory` at the observed working set rounded down to a
     round Gi (the floor pins the recommendation, it is not the request).
   - **Cap** — target exceeds node allocatable (~16Gi here). The fix is
     `maxAllowed`; an oversized request parks the pod Pending forever. First
     confirm the memory is cgroup-resident — GPU-resident weights
     (llama.cpp RPC) and page-cache-heavy services (forgejo) are "normal" at
     40Gi+.
   - **No action** — restarts stale or exit-code-1 app errors; a floor cannot
     fix an app bug. Say so and move on.
4. **Land through the standard flow** — issue first (acceptance = the live
   `kubectl get vpa` jsonpath checks plus `flux get kustomization` Ready), one
   branch off fresh `origin/main`, `resourcePolicy.containerPolicies` block
   per app VPA under `apps/<app>/base/`, kustomize-render gate, PR. Floors are
   inert until Flux applies — verify the live spec after reconcile, not the
   merge.

## Gotchas

- Only the literal `OOMKilled` reason (exit 137) indicts memory. Exit 255 /
  `Unknown` terminations are not OOM; counting restarts without the reason
  flags healthy pods.
- `kubectl get vpa` has no short name on this cluster; `-o json` works — parse
  JSON, not table output.
- The 250Mi floor is the recommender's global default, not a per-VPA
  `minAllowed`; do not read it out of fields that do not exist.
- VPA InPlace mode sets requests live, overriding the STS template — before
  forcing a reschedule, cap `maxAllowed` or set `updateMode: Off` on the
  VPA, or the recommender re-drifts the request the moment the pod
  restarts.
- `exitCode 137` with NO container memory limit is a NODE-level OOM kill
  from overcommit, not a cgroup limit hit (immich on nalsha: requests-only
  pod killed while the node was oversubscribed). A floor cannot fix node
  overcommit — check node allocatable vs requested before sizing anything.
- Size floors from the live cluster (`kubectl describe pod` working set,
  VPA `target`/`upperBound`), never from the STS template — the template's
  requests are whatever was last committed, not what runs.

## Verification

Each landed floor: `kubectl get vpa <name> -n <ns> -o jsonpath` shows the
`minAllowed` block; `flux get kustomization` Ready; landed pods stable with no
new eviction events.
