# hermes-agent

Hermes Agent gateway (`gateway run --replace`) as a single-replica StatefulSet
for the nishir-automata stack. An rclone init container syncs config.yaml and
SOUL.md from the startup-config secret into /opt/data; env comes from the SOPS
`hermes-agent` secret and an SSH key secret mounts into /root/.ssh. Data,
profiles, and skills live on three PVCs. The base Service has no ports;
components expose the API (:8642), A2A (:9900), dashboard (:9119), and webhook
(:8644), each with an HTTPRoute pair (proxy + 301 redirect) on the shared
`hermes-agent` Gateway: `automata` (dashboard), `api.automata` (api-server),
`a2a.automata` (a2a).

## Layout

- `base/` — sts.yaml, svc.yaml (no ports), netpol.yaml (no ingress), pvc.yaml
  (data/profiles/skills), vpa.yaml, rclone.conf ConfigMap.
- `components/` — a2a, api, browser, dashboard, honcho, webhook; each patches
  the sts (plus svc/netpol where it exposes a port) and owns its HTTPRoute +
  redirect (a2a, api-server, dashboard).
- `overlays/nishir/` — SOPS env, startup-config and SSH secrets, PVC patches,
  Gateway (http/https + per-hostname certs), route hostname/parent patches.
- `overlays/nishir-tailnet/` — GatewayClass/EnvoyProxy (tailscale LB),
  taila659a.ts.net hostnames, netpol for tailscale-system.
