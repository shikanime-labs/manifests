# honcho-postgres

PostgreSQL 15 (pgvector image) backing store for honcho on :5432, with a 512Mi
`honcho-postgres-data` PVC and an init.sql ConfigMap (pgvector extension +
schema bootstrap) mounted into the entrypoint's initdb dir. Credentials come
from a SOPS basic-auth secret; the netpol admits only honcho pods.

## Layout

- `base/` — StatefulSet, Service (:5432), PVC, init.sql ConfigMap, VPA, netpol.
- `overlays/nishir/` — namespace, PVC patch, basic-auth secret generator
  (disableNameSuffixHash).
- `overlays/nishir-tailnet/` — namespace + database labels.
