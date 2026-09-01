# synapse-proxy

Envoy Gateway in front of synapse, published as `matrix` over Tailscale
(funnel). Routes `matrix.i.shikanime.studio` to synapse's https :8448
(`Host matrix.taila659a.ts.net`), plus the mautrix bridge-discovery
well-known listing the eight matrix-*.i.shikanime.studio bridge endpoints. The
`matrix-discord-media` hostname is routed straight to the discord bridge for
direct media downloads. TLS terminates on :443 from the
`studio-shikanime-i-matrix` Certificate.

## Layout

- `base/` — httproute.yaml (matrix, matrix-discord-media, matrix-redirect).
- `overlays/nishir/` — BackendTLSPolicy for synapse's TLS backend, Gateway
  (synapse-proxy), patch-httproute (hostnames + parentRefs).
- `overlays/nishir-tailnet/` — GatewayClass, EnvoyProxy (tailscale LB),
  EnvoyPatchPolicy for the static mautrix well-known response.
