# blocky-valkey

Valkey 9 (valkey/valkey 9-alpine) on :6379 as blocky's redis cache
(redis.address blocky-valkey.shikanime.svc.cluster.local:6379, required).
Persistent: AOF enabled (--appendonly yes) on a 512Mi local-path volume.
Only the blocky pod may connect (NetworkPolicy).

## Layout

- `base/` — StatefulSet, Service, NetworkPolicy, VPA.
- `overlays/nishir/` — base as-is, no patches.
- `overlays/nishir-tailnet/` — `nishir-platform` labels.
