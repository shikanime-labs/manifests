# VPA minAllowed memory floor tuning

<!-- owner: shikanime studio | zone: internal | purpose: generic methodology to decide which workloads need a VPA memory floor, and how to size and land it -->

## Problem

A workload crashloops under node memory pressure with no container OOMKilled
event: the VPA InPlace recommender let its request drift below the real
working set after recommender history reset. This runbook is the generic
recipe for a fleet-wide `minAllowed` audit; the 2026-09 pass (issues #2317,
#2318) is kept as the worked example.

Scope: **memory only**. CPU floors fight throttling, not eviction — a
CPU-starved pod degrades, it does not die. Storage is PVC territory
(`allowVolumeExpansion`), not VPA. If the symptom is CPU or disk, this is the
wrong runbook.

## Methodology

### 1. Scan every VPA, compare recommendation vs declared floor

One JSON dump, one script, no pipes. Compare
`status.recommendation.containerRecommendations[].lowerBound.memory` against
`spec.resourcePolicy.containerPolicies[].minAllowed.memory` per container:

```python
# audit script shape; flag rules below
# ponytail: pod matching by name prefix, ownerRef join if prefixes collide
for v in vpas:
    for cr in v.status.recommendation.containerRecommendations:
        mn, lo = floor(v, cr), mem(cr.lowerBound.memory)
        if (mn is None and lo >= 300) or (mn and lo > mn * 1.5):
            flag(v.namespace, v.name, cr.containerName, mn, lo, cr.target.memory)
```

Flag rule: **no floor with lowerBound ≥ 300Mi**, or a floor more than 1.5×
below the lower bound. Nothing below 300Mi has ever warranted a floor on this
fleet; revisit the threshold if node sizes change.

### 2. Resolve pods by owner, never by name guess

Pod names guessed from VPA names return "not found" and burn a cycle. Join on
namespace + container name, or resolve via ownerReferences.

### 3. Gather kill evidence before any verdict

For every flagged VPA, read the workload's live pods:

```bash
kubectl get pod -n <ns> -o json | jq -r '
  .items[] | .metadata.name as $p | .status.containerStatuses[]? |
  "\($p) \(.name) rst=\(.restartCount) last=\(.lastState.terminated.reason // "-")"'
```

Verdicts are evidence-shaped, three kinds only:

- **Floor** — recent `OOMKilled` or a working set that tracks the lowerBound.
  Set `minAllowed.memory` at the observed working set, rounded down to a
  round Gi (the floor pins the recommendation, it is not the request).
- **Cap** — recommendation `target` exceeds node allocatable (~16Gi here).
  The fix is `maxAllowed`, not a min: an oversized stamped request parks the
  pod Pending forever on next reschedule. Before capping, confirm the memory
  is really cgroup-resident — GPU-resident weights (llama.cpp RPC) and
  page-cache-heavy services (forgejo) may be "normal" at 40Gi+ target.
- **No action** — restarts stale (last termination weeks old) or exit-code-1
  app errors. Crashloops with `Error`/`Unknown` exits are app bugs; a VPA
  floor cannot fix them. Say so and move on.

### 4. Land floors through the standard flow

Issue first (acceptance = the three `kubectl get vpa ... -o jsonpath` checks
plus `flux get kustomization` Ready), one branch off fresh `origin/main`,
`resourcePolicy.containerPolicies` block per app VPA under `apps/<app>/base/`,
kustomize-render gate, then the PR workflow. Floors are inert until Flux
applies — verify the live spec after reconcile, not the merge.

## Worked example (2026-09 pass)

- Scanned 65 VPAs; 12 app flags → 3 floors landed: qbittorrent 4Gi,
  immich-ml 3Gi, copyparty 1.5Gi (#2318).
- forgejo (target 41.4Gi) and llama-cpp (74.5Gi) flagged as cap candidates —
  owner ruled both "normal" (page cache / GPU weights); left untouched.
- 3 infra flags (gatekeeper ×2, virt-operator): restarts stale or exit-1;
  no action. Zero OOMKilled fleet-wide outside the already-floored immich.

## Traps

- **Exit 255 / `Unknown` terminations are not OOM.** Only the literal
  `OOMKilled` reason (exit 137) indicts memory. Counting restarts without
  reading the reason flags healthy pods.
- **`kubectl get vpa` has no short name on this cluster** — but `-o json`
  works; a failing `jsonpath` on the short name is a client-side error, not
  cluster drift. Parse JSON, not table output.
- **Recommender targets above node capacity are the real hazard**, the
  inverse of the floor problem: the urgent fix is a cap, and a cap needs the
  GPU/page-cache sanity check first or you strangle a healthy workload.
- **VPA flags and pod names do not correspond** — resolve pods by owner or
  container name (step 2) or every evidence query misses.
- **The 250Mi floor is the recommender's global default**, not a per-VPA
  `minAllowed`; do not read it out of `minAllowed` fields that do not exist.

## References

- https://github.com/shikanime-labs/manifests/pull/2313 — immich floor,
  origin of the pattern
- https://github.com/shikanime-labs/manifests/issues/2317 — audit issue with
  acceptance checks
- https://github.com/shikanime-labs/manifests/pull/2318 — floors landing PR
