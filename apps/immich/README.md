# immich

Immich server (ghcr.io/immich-app/immich-server v1.144.1): self-hosted photo
manager on HTTP :2283, plus a :8081 metrics port scraped by vmagent. Uploads
live on the `data` volumeClaimTemplate (64Gi, `nishir-nearline` on nishir)
beside a read-only `timeline-data` PVC. DB credentials come from files under
/run/secrets/immich-postgres (DB_USERNAME_FILE / DB_PASSWORD_FILE /
DB_DATABASE_NAME_FILE); it also reaches immich-valkey :6379 and
immich-ml :3003. The NetworkPolicy admits only tailscale-system on http and
vmagent on metrics.

## Layout

- `base/` — StatefulSet, Service, NetworkPolicy, VPA.
- `components/monitoring/` — VMServiceScrape on /metrics (60s).
- `overlays/nishir/` — `immich` Secret (.enc.env), PVC swap to
  `immich-data` + `timeline-data`, monitoring component.
- `overlays/nishir-tailnet/` — Tailscale Ingress, SOPS `config.yaml`
  (externalDomain immich.taila659a.ts.net, ffmpeg QSV, SMTP, Dex OAuth) as
  `immich-config` Secret.
