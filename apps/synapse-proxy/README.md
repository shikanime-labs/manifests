# synapse-proxy

Caddy reverse proxy in front of synapse, published as `matrix` over
Tailscale (funnel). Serves /.well-known/matrix/* and /_matrix/* by
proxying to synapse's https :8448 (`tls_server_name synapse`), plus the
mautrix bridge-discovery well-known listing the eight
matrix-*.taila659a.ts.net bridge endpoints. The `matrix-discord-media`
hostname is routed straight to the discord bridge for direct media
downloads. TLS terminates on :8448 from the `synapse-proxy-tls`
Certificate (tls component); :8008 stays plain.

## Layout

- `base/` — sts.yaml (caddy, TCP probes, /var/caddy PVC), svc.yaml
  (http :8008), netpol.yaml (ingress from synapse on :8448), pvc, vpa.
- `components/tls/` — https :8448 port and cert mount for Caddy.
- `overlays/nishir/` — Certificate `synapse-proxy-tls`, PVC patch.
- `overlays/nishir-tailnet/` — Caddyfile ConfigMap, `matrix` Ingress
  (tailscale, funnel) on the https port, netpol for tailscale-system.
