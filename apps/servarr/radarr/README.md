# radarr

Radarr (lscr.io/linuxserver/radarr 6.3.0) manages the movie library: it queries
prowlarr for releases and hands them to qbittorrent. Web UI on :7878 (svc
`radarr`); the TLS component re-exposes it on https :9898, admitted from
prowlarr, bazarr, seerr and jellyfin by the NetworkPolicy.

## Layout

- `base/` — StatefulSet (http :7878, `/ping` probes
  seeding config.xml from the `radarr` Secret), Service, PVC `radarr-config`
  (2Gi), NetworkPolicy (ingress from prowlarr, bazarr, seerr, jellyfin), VPA.
- `components/tls/` — HTTPS :9898 with a pkcs12 keystore from Secret
  `radarr-tls`.
- `overlays/nishir/` — Certificate (nishir ClusterIssuer), config.xml and
  pkcs12-password SOPS Secrets, mounts `movies-data` and
  `downloads-radarr-data`.
- `overlays/nishir-tailnet/` — tailscale Ingress (host `radarr`), netpol for
  `tailscale-system`, `nishir-media` labels.
