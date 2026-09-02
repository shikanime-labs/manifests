# maintainerr

Maintainerr (ghcr.io/maintainerr/maintainerr v3.26.0) is the collections
manager for the media stack: it watches radarr/sonarr libraries and
deletes stale items when their watch windows expire. Web UI on :6246
(svc `maintainerr`) behind a tailscale Envoy Gateway; data on PVC
`maintainerr-config` (1Gi) at `/opt/data`.

## Layout

- `base/` — StatefulSet (http :6246, `/api/health/live` + `/api/health/ready`
  probes), Service, PVC `maintainerr-config`, NetworkPolicy (deny-all
  ingress; the gateway plane is cross-namespace), VPA.
- `overlays/nishir/` — cluster-CA cert, Gateway, PVC pinned to
  `nishir-standard`; no secrets.
- `overlays/nishir-tailnet/` — tailscale BYOD EnvoyProxy (LB svc
  `maintainerr-proxy`), route hostnames, `nishir-media` labels.

The studio hostname `maintainerr.i.shikanime.studio` cert is issued by
`configs/cert-manager/overlays/nishir/cert.yaml`.
