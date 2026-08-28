# dex

OIDC identity provider for the nishir platform: a single-replica
StatefulSet running `dex serve /etc/dex/config.yaml` from the
`dex-config` Secret (SOPS-encrypted `config.enc.yaml`), mounted
read-only. Serves HTTP :5556 plus telemetry :5558; the Service keeps
ClientIP affinity and the NetworkPolicy admits both ports.

## Layout

- `base/` — sts.yaml (config Secret volume), svc.yaml (http, telemetry),
  netpol.yaml, vpa.yaml.
- `components/monitoring/` — vmservicescrape for the telemetry port.
- `components/tls/` — patches the STS (serving certs) and adds an https
  Service port.
- `overlays/nishir/` — cluster CA cert plus tls/monitoring components.
- `overlays/nishir-tailnet/` — Tailscale Ingress on
  `accounts.taila659a.ts.net`, secretGenerator feeding `dex-config`
  from `dex/config.enc.yaml`.
