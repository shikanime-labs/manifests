# servarr

The -arr media management stack: one app per medium, all built the same way
(base + components/tls + overlays). Each member is a single-replica StatefulSet
with a Longhorn config PVC, an rclone init container seeding config.xml from a
SOPS Secret, a TLS component flipping the listener to HTTPS, and a tailscale
Ingress on `nishir-tailnet`. NetworkPolicies wire the members to prowlarr
(indexers), qbittorrent (downloads), bazarr (subtitles) and jellyfin/seerr
(playback/requests).

## Members

- `lidarr/` — music (svc :8686). Queries prowlarr; media on `music-data`.
- `radarr/` — movies (svc :7878). Queries prowlarr; reachable from bazarr, seerr
  and jellyfin; media on `movies-data`.
- `sonarr/` — TV shows (svc :8989). Queries prowlarr; reachable from bazarr,
  seerr and jellyfin; media on `shows-data`.
- `whisparr/` — adult content (svc :6969). Queries prowlarr only; media on
  `sukebe-videos-data` and `sukebe-scenes-data`.
