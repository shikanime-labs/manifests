# synapse

Matrix homeserver (matrixdotorg/synapse) for the shikanime office Matrix
deployment. Single-replica StatefulSet serving the client-server API on :8008
and /metrics on :9090 (scraped by a VMServiceScrape); the tls component adds the
federation port :8448 with a cert from the nishir ClusterIssuer. The
startup-config volume projects homeserver.yaml plus the mautrix-* registration
and doublepuppet files for all eight bridges, so synapse loads every bridge as
an appservice on boot. NetworkPolicy admits only the mautrix bridges,
hermes-agent, and the Envoy data plane (envoy-gateway-system).

An Envoy Gateway fronts the homeserver, published as `matrix` over Tailscale
(funnel). Routes `matrix.i.shikanime.studio` to synapse's https :8448
(`Host matrix.taila659a.ts.net`), plus the mautrix bridge-discovery well-known
listing the eight matrix-*.i.shikanime.studio bridge endpoints. The
`matrix-discord-media` hostname is routed straight to the discord bridge for
direct media downloads. TLS terminates on :443 from the
`studio-shikanime-i-matrix` Certificate.

## Layout

- `base/` — sts.yaml (1 replica, 64Gi PVC), svc.yaml (http :8008, metrics
  :9090), netpol.yaml, pvc.yaml, vpa.yaml, httproute.yaml (matrix,
  matrix-discord-media, matrix-redirect).
- `components/monitoring/` — VMServiceScrape on the metrics port.
- `components/tls/` — https :8448 port, TLS secret mount, probes.
- `overlays/nishir/` — Certificate `synapse-tls` (nishir issuer), PVC pin to
  `nishir-standard`, 2.5g-network node affinity, Gateway (synapse),
  BackendTLSPolicy for synapse's TLS backend, patch-httproute (hostnames +
  parentRefs).
- `overlays/nishir-tailnet/` — SOPS homeserver.yaml + log config
  secretGenerator; GatewayClass + EnvoyProxy (tailscale LB), HTTPRouteFilter
  for the static mautrix well-known response; netpol opens metrics to vmagent
  and https to envoy-gateway-system.
