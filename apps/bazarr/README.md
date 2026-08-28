# bazarr

Bazarr (lscr.io/linuxserver/bazarr 1.6.0) manages subtitles for the media stack:
it downloads subs for the movies and shows libraries and is reachable from
prowlarr for indexer lookups. Web UI on :6767 (svc `bazarr`) behind a tailscale
Ingress; config on PVC `bazarr-config` (512Mi).

## Layout

- `base/` — StatefulSet (http :6767, TCP probes, PUID/PGID/TZ), Service, PVC
  `bazarr-config`, NetworkPolicy (ingress from prowlarr only), VPA; an rclone
  init container seeds `config.yaml` from the `bazarr` Secret.
- `overlays/nishir/` — PVC pinned to `nishir-standard`, mounts `movies-data` and
  `shows-data`, Secret `bazarr` (`config.enc.yaml`).
- `overlays/nishir-tailnet/` — tailscale Ingress (host `bazarr`), netpol opened
  to `tailscale-system`, `nishir-media` labels.
