# seerr

Seerr (ghcr.io/seerr-team/seerr v3.4.1) is the request front-end for the
media stack: users request movies and shows that radarr and sonarr then
fulfill, and jellyfin can reach it for deep links. Web UI on :5055 (svc
`seerr`) behind a tailscale Ingress; config on PVC `seerr-config` (512Mi).

## Layout

- `base/` — StatefulSet (http :5055, `/api/v1/status` probes), Service, PVC
  `seerr-config`, NetworkPolicy (ingress from jellyfin only), VPA.
- `overlays/nishir/` — PVC pinned to `nishir-standard`; no secrets.
- `overlays/nishir-tailnet/` — tailscale Ingress (host `seerr`), netpol
  opened to `tailscale-system`, `nishir-media` labels.
