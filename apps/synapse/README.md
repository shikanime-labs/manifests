# synapse

Matrix homeserver (matrixdotorg/synapse) for the shikanime office
Matrix deployment. Single-replica StatefulSet serving the client-server
API on :8008 and /metrics on :9090 (scraped by a VMServiceScrape); the
tls component adds the federation port :8448 with a cert from the nishir
ClusterIssuer. The startup-config volume projects homeserver.yaml plus
the mautrix-* registration and doublepuppet files for all eight bridges,
so synapse loads every bridge as an appservice on boot. NetworkPolicy
admits only the mautrix bridges, synapse-proxy, and hermes-agent.

## Layout

- `base/` — sts.yaml (1 replica, 64Gi PVC), svc.yaml (http :8008,
  metrics :9090), netpol.yaml, pvc.yaml, vpa.yaml.
- `components/monitoring/` — VMServiceScrape on the metrics port.
- `components/tls/` — https :8448 port, TLS secret mount, probes.
- `overlays/nishir/` — Certificate `synapse-tls` (nishir issuer), PVC
  pin to `nishir-standard`, 2.5g-network node affinity.
- `overlays/nishir-tailnet/` — SOPS homeserver.yaml + log config
  secretGenerator; netpol opens metrics to vmagent and https to
  tailscale-system.
