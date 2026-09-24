# forgejo

Git forge (GitHub-Actions-compatible) running the rootless Forgejo image with
`USER_UID`/`USER_GID` set to 1000 and `TZ=Europe/Paris`. Serves HTTP on :80
(Service `forgejo`) and SSH on :22 (LoadBalancer Service `git`); data on the
128Gi `forgejo-data` PVC. The NetworkPolicy admits HTTP/SSH from the
gitea-mirror pods and the monitoring vmagent.

## Layout

- `base/` — sts.yaml (3000/2222, app.ini from the `forgejo-config` Secret),
  svc.yaml (forgejo http + git ssh), pvc.yaml (128Gi), netpol.yaml, vpa.yaml.
- `components/monitoring/` — vmservicescrape for metrics.
- `components/tls/` — serving certs plus https Service port.
- `overlays/nishir/` — cluster CA cert, monitoring/tls components, PVC and sts
  patches (2.5GbE node affinity).
- `overlays/nishir-tailnet/` — Tailscale Ingress, git Service on Tailscale
  (`tag:git`), app.ini from `forgejo/app.enc.ini`.
