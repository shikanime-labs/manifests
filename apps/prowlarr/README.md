# prowlarr

Prowlarr (lscr.io/linuxserver/prowlarr 2.5.2) is the indexer aggregator for
the media stack: lidarr, radarr, sonarr and whisparr query it for releases.
Serves on :9696 (svc `prowlarr`); the TLS component re-exposes it on https
:6969, which the base NetworkPolicy admits from all four -arr apps.

## Layout

- `base/` — StatefulSet (http :9696, `/ping` probes), Service, PVC
  `prowlarr-config` (2Gi), NetworkPolicy (ingress from the -arr apps), VPA.
- `components/tls/` — HTTPS :6969 with a pkcs12 keystore from Secret
  `prowlarr-tls`.
- `overlays/nishir/` — Certificate from the nishir ClusterIssuer (pkcs12
  keystore), PVC patch, `prowlarr-pkcs12-password` SOPS env secret.
- `overlays/nishir-tailnet/` — tailscale Ingress (host `prowlarr`), netpol
  for `tailscale-system`, `nishir-media` labels.
