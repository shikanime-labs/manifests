# immich-valkey

Valkey 7 (valkey/valkey 7-alpine) on :6379 as the immich stack's cache
(REDIS_HOSTNAME immich-valkey). Ephemeral by design: persistence is disabled
(--save "" --appendonly no) and the data dir is an emptyDir. Only the immich pod
may connect (NetworkPolicy).

## Layout

- `base/` — StatefulSet, Service, NetworkPolicy, VPA.
- `overlays/nishir/` — base as-is, no patches.
- `overlays/nishir-tailnet/` — `nishir-media` labels.
