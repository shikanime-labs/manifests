# copyparty

Multi-protocol file server: a single-replica StatefulSet serving HTTP on :3923,
with FTP/FTPS/SFTP layered on via components. Config comes from a ConfigMap
(`config.conf`) plus a 512Mi config PVC; the nishir overlay mounts the
media/share PVCs (archives, movies, music, ...) under /data. The NetworkPolicy
admits HTTP, ftp-control, ftp data 12000-12099, ftps and sftp from
`tailscale-system`.

Auth is anonymous-first: the catch-alls strip `X-WEBAUTH-USER`/`X-Id-Token`,
while the OIDC-gated `copyparty-sso` route (Envoy
session cookie or `/?h`) is where the gateway mints identity for members.

## Layout

- `base/` — sts.yaml (:3923), svc.yaml (http), pvc.yaml (config 512Mi),
  netpol.yaml, vpa.yaml.
- `components/ftp/` — LoadBalancer Service `ftp` (21 + 12000-12099) and STS port
  patch.
- `components/{ftps,sftp,tls,zeroconf}/` — optional protocol/TLS/ zeroconf
  patches.
- `overlays/nishir/` — cluster CA cert, all components, data PVC mounts, 2.5GbE
  node affinity.
- `overlays/nishir-tailnet/` — Tailscale LB Gateway, config from
  `copyparty/config.conf`.
