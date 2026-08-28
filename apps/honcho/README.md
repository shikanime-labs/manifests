# honcho

Honcho conversational memory server (ghcr.io/plastic-labs/honcho) on :8000,
scaled by an HPA (CPU 70%, 1-3 replicas). DB_* credentials come from the
honcho-postgres secret and build a psycopg connection to
`honcho-postgres.shikanime.svc.cluster.local:5432`; an alembic init
container migrates the schema before the app starts. Netpol admits only
hermes-agent pods and vmagent.

## Layout

- `base/` — Deployment (alembic-upgrade initContainer, health probes),
  Service (:8000), HPA, VPA, netpol.
- `components/monitoring/` — VMServiceScrape on /metrics.
- `overlays/nishir/` — namespace, config.toml ConfigMap, SOPS env Secret,
  monitoring component.
- `overlays/nishir-tailnet/` — Tailscale Ingress, netpol patch admitting
  tailscale-system, labels.
