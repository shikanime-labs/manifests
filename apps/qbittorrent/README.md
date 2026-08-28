# qbittorrent

qbittorrent-nox (5.2.3-1) is the torrent downloader for the media stack: the
-arr apps hand it downloads, stored per-app under `/downloads` (with
`incomplete/` subfolders) on the `downloads-data` PVCs. Web UI on :8080 (svc
`qbittorrent`), tracker on :6881 tcp+udp via the `qbittorrent-tracker`
LoadBalancer, republished over Tailscale by the tailnet overlay.

## Layout

- `base/` — StatefulSet (http :8080, bittorrent :6881 tcp/udp), Services
  `qbittorrent` + `qbittorrent-tracker` (LoadBalancer), PVC
  `qbittorrent-config`, NetworkPolicy (ingress from all -arr apps and
  qbittorrent-cleanup), VPA.
- `components/tls/` — web UI over HTTPS :8080 (tls.crt/key from Secret
  `qbittorrent-tls`).
- `overlays/nishir/` — Certificate, PVC patch, mounts `downloads-data` plus
  per-arr subPath PVCs (radarr/sonarr/lidarr/whisparr + incomplete/).
- `overlays/nishir-tailnet/` — tailscale Ingress, netpol opened to
  `tailscale-system` and the tracker ports, `qbittorrent-tracker` published with
  `loadBalancerClass: tailscale` (tag:bittorrent).
