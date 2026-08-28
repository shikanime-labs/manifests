# qbittorrent-cleanup

A CronJob running ghcr.io/shikanime-labs/xqbit/qbittorrent-cleanup every two
minutes against qbittorrent (https://qbittorrent.shikanime.svc.cluster.local,
credentials from the `qbittorrent-cleanup` Secret) to prune torrents. It has
no Service, PVC or NetworkPolicy of its own — qbittorrent's NetworkPolicy
admits it.

## Layout

- `base/` — CronJob only (schedule `*/2 * * * *`, concurrency Forbid,
  QBT_URL env).
- `overlays/nishir/` — namespace + `qbittorrent-cleanup` Secret
  (`.enc.env`).
- `overlays/nishir-tailnet/` — `nishir-media` labels only.
