# whisparr

Whisparr (ghcr.io/hotio/whisparr v3-3.1.0.2040) manages the adult library: it
queries prowlarr for releases and hands them to qbittorrent. Web UI on :6969
(svc `whisparr`); the TLS component re-exposes it on https :9898, admitted
from prowlarr only by the NetworkPolicy.

## Layout

- `base/` — StatefulSet (http :6969, `/ping` probes, rclone init container
  seeding config.xml from the `whisparr` Secret), Service, PVC
  `whisparr-config` (8Gi), NetworkPolicy (ingress from prowlarr), VPA.
- `components/tls/` — HTTPS :9898 with a pkcs12 keystore from Secret
  `whisparr-tls`.
- `overlays/nishir/` — Certificate (nishir ClusterIssuer), config.xml and
  pkcs12-password SOPS Secrets, mounts `sukebe-videos-data` (`/data/videos`
  with `sukebe-scenes-data` at `/data/videos/Import`) and
  `downloads-whisparr-data`.
- `overlays/nishir-tailnet/` — tailscale Ingress (host `whisparr`), netpol
  for `tailscale-system`, `nishir-media` labels.
