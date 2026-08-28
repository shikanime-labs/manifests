# sonarr

Sonarr (lscr.io/linuxserver/sonarr 4.0.19) manages the TV show library: it
queries prowlarr for releases and hands them to qbittorrent. Web UI on :8989
(svc `sonarr`); the TLS component re-exposes it on https :9898, admitted from
prowlarr, bazarr, seerr and jellyfin by the NetworkPolicy.

## Layout

- `base/` — StatefulSet (http :8989, `/ping` probes, rclone init container
  seeding config.xml from the `sonarr` Secret), Service, PVC `sonarr-config`
  (4Gi), NetworkPolicy (ingress from prowlarr, bazarr, seerr, jellyfin), VPA.
- `components/tls/` — HTTPS :9898 with a pkcs12 keystore from Secret
  `sonarr-tls`.
- `overlays/nishir/` — Certificate (nishir ClusterIssuer), config.xml and
  pkcs12-password SOPS Secrets, mounts `shows-data` and `downloads-sonarr-data`.
- `overlays/nishir-tailnet/` — tailscale Ingress (host `sonarr`), netpol for
  `tailscale-system`, `nishir-media` labels.
