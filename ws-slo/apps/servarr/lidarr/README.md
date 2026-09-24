# lidarr

Lidarr (lscr.io/linuxserver/lidarr 3.1.0) manages the music library: it queries
prowlarr for releases and hands them to qbittorrent. Web UI on :8686 (svc
`lidarr`); the TLS component re-exposes it on https :6868, which the
NetworkPolicy admits from prowlarr.

## Layout

- `base/` — StatefulSet (http :8686, `/ping` probes, rclone init container
  seeding config.xml from the `lidarr` Secret), Service, PVC `lidarr-config`
  (2Gi), NetworkPolicy (ingress from prowlarr), VPA.
- `components/tls/` — HTTPS :6868 with a pkcs12 keystore from Secret
  `lidarr-tls`.
- `overlays/nishir/` — Certificate (nishir ClusterIssuer), config.xml and
  pkcs12-password SOPS Secrets, mounts `music-data` and `downloads-lidarr-data`.
- `overlays/nishir-tailnet/` — tailscale Ingress (host `lidarr`), netpol for
  `tailscale-system`, `nishir-media` labels.
