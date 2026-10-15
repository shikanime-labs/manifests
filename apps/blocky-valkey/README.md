# blocky-valkey

Valkey 9 (valkey/valkey 9-alpine) on :6379 as blocky's redis cache
(redis.address blocky-valkey.shikanime.svc.cluster.local:6379, required).
Ephemeral by design:
persistence is disabled (--save "" --appendonly no) and the data dir is an
emptyDir. Only the blocky pod may connect (NetworkPolicy).

## Layout

- `base/` — StatefulSet, Service, NetworkPolicy, VPA.
- `overlays/nishir/` — base as-is, no patches.
- `overlays/nishir-tailnet/` — `nishir-platform` labels.
