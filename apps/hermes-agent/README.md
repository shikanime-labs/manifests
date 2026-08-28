# hermes-agent

Hermes Agent gateway (`gateway run --replace`) as a single-replica
StatefulSet for the nishir-automata stack. An rclone init container
syncs config.yaml and SOUL.md from the startup-config secret into
/opt/data; env comes from the SOPS `hermes-agent` secret and an SSH key
secret mounts into /root/.ssh. Data, profiles, and skills live on three
PVCs. The base Service has no ports; components expose the API (:8642),
A2A (:9900), dashboard (:9119), and webhook (:8644), each published as a
tailscale Ingress (`automata`, `nishir`, `automata-a2a`,
`automata-dashboard`, `automata-webhook`).

## Layout

- `base/` — sts.yaml, svc.yaml (no ports), netpol.yaml (no ingress),
  pvc.yaml (data/profiles/skills), vpa.yaml, rclone.conf ConfigMap.
- `components/` — a2a, api, browser, dashboard, honcho, webhook; each
  patches the sts (plus svc/netpol where it exposes a port).
- `overlays/nishir/` — SOPS env, startup-config and SSH secrets,
  PVC patches.
- `overlays/nishir-tailnet/` — five tailscale Ingresses, netpol for
  tailscale-system.
