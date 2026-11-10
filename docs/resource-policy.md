# Uniform resource request policy — nishir fleet

Codifies the sizing rule every workload in this repo follows, replaces
per-workload judgement calls.

## The rule

| workload class | template request | VPA |
|---|---|---|
| VPA-managed (default) | = `status.recommendation.target` | InPlace, cap 2-4x |
| GPU / unified-memory | host-side peak + GTT share | memory out of VPA scope |
| cache / page-cache floor | peak RSS × 1.3 (explicit) | minAllowed = floor |

- **request** is what the scheduler books; it must equal the workload's p90
  measured usage (VPA `status.recommendation.target`).
- **limits do not exist** on this fleet — a limit only ever throttles; bursts
  draw from spare node capacity.
- **efficiency** is `usage / request`. Healthy band 40-85%. Under 30% is
  over-requested; over 100% is fine only when the container has no limit.
- **drift** is `request / VPA target`. 0.8-2.0× is in-band. Over 2× for two
  consecutive audits = land a re-alignment PR. Under 0.8× = raise before the
  next node-pressure event.
- A request above the VPA target is legitimate only when written down as a
  floor class (GPU, page cache) or a VPA cap (forgejo's 16Gi cap against a
  59.7Gi uncapped target).

## Enforcement

The audit re-derives per workload: replicas, request, measured use, efficiency
band, VPA target, drift. Any workload outside band for two consecutive audits
becomes a PR. Charts ship requests in HelmRelease values; apps in the STS
template. Both are re-read from `kubectl top` / VPA status at audit time,
never from defaults.
