# qbittorrent

qbittorrent-nox (5.2.3-1) is the torrent downloader for the media stack: the
-arr apps hand it downloads, stored per-app under `/downloads` (with
`incomplete/` subfolders) on the `downloads-data` PVCs. Web UI on :8080 (svc
`qbittorrent`), BitTorrent on :6881 tcp+udp, both served via the `qbittorrent`
Envoy Gateway (no separate tracker Service).

## Layout

- `base/` — StatefulSet (http :8080, bittorrent :6881 tcp/udp), Service
  `qbittorrent` (http + bittorrent ports), PVC `qbittorrent-config`,
  NetworkPolicy (ingress from all -arr apps and qbittorrent-cleanup), VPA.
- `components/tls/` — web UI over HTTPS :8080 (tls.crt/key from Secret
  `qbittorrent-tls`).
- `overlays/nishir/` — Certificate, PVC patch, mounts `downloads-data` plus
  per-arr subPath PVCs (radarr/sonarr/lidarr/whisparr + incomplete/).
- `overlays/nishir-tailnet/` — Envoy Gateway ingress: HTTPRoute for the web
  UI, TCPRoute for the `bittorrent` listener (6881), UDPRoute for the tracker
  (6881), netpol opened to `envoy-gateway-system`.
