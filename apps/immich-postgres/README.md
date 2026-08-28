# immich-postgres

PostgreSQL backing the immich stack (ghcr.io/immich-app/postgres
14-vectorchord0.4.3-pgvectors0.2.0, port :5432) with the vectorchord and
pgvector extensions immich needs. Credentials come from the `immich-postgres`
basic-auth Secret (POSTGRES_DB/USER/PASSWORD); data sits on the 4Gi
`immich-postgres-data` PVC. Only the immich pod may connect (NetworkPolicy).

## Layout

- `base/` — StatefulSet, Service, PVC, NetworkPolicy, VPA.
- `overlays/nishir/` — SOPS basic-auth Secret, PVC pinned to
  `nishir-standard`.
- `overlays/nishir-tailnet/` — `nishir-media` labels.
