# metatube

Metatube server (ghcr.io/metatube-community/metatube-server 1.4.0): the
metadata backend consumed by jellyfin — the NetworkPolicy admits only the
jellyfin pod on http. The Service fronts :80 → container :8080; a 512Mi
`metatube-data` PVC holds the SQLite DB at /data/metatube.db. Scraping
routes through HTTP(S)_PROXY (https://secure.mse.waseda.ac.jp).

## Layout

- `base/` — StatefulSet, Service, PVC, NetworkPolicy, VPA.
- `overlays/nishir/` — `metatube` Secret (.enc.env), PVC pinned to
  `nishir-standard` + volumeName.
- `overlays/nishir-tailnet/` — Tailscale Ingress, `nishir-media` labels.
