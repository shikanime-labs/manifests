# blocky-valkey

Valkey 9 (valkey/valkey 9-alpine) on :6379 as blocky's redis cache
(redis.address blocky-valkey.shikanime.svc.cluster.local:6379, required).
Stateless: 3-replica Deployment, in-memory only — it's a DNS cache, data is
disposable. Rolling updates with maxUnavailable 0 keep capacity during deploys.
Only the blocky pod may connect (NetworkPolicy).

## Layout

- `base/` — Deployment, Service, NetworkPolicy, VPA.
- `overlays/nishir/` — base as-is, no patches.
- `overlays/nishir-tailnet/` — `nishir-platform` labels.
