# catbox

KubeVirt VM running the hermes-agent natively via the upstream NixOS module
(see shikanime-labs/machines, hosts/catbox), published as
`ghcr.io/shikanime-labs/machines/catbox:latest` containerDisk (NixOS qcow2,
no CDI). SSH :22 and mDNS :5353/UDP are exposed over a LoadBalancer Service;
boots on amd64 nodes with a 64Gi `catbox-workspaces` PVC.

Serves the automata stack — dashboard :9119, api-server :8642, a2a :9900. All
automata hostnames route through the envoy Gateway and backend to the `catbox`
Service.

## Layout

- `base/` — VirtualMachine (runStrategy Always), Service (:22 tcp, :5353 udp,
  :9119, :8642, :9900), workspaces PVC, HTTPRoutes (`automata` dashboard,
  `api.automata` api-server, `a2a.automata` a2a) each with a 301 redirect twin
  on the http listener.
- `overlays/nishir/` — namespace, Gateway `hermes-agent` (http/https +
  per-hostname certs, `*.i.shikanime.studio`).
- `overlays/nishir-tailnet/` — GatewayClass/EnvoyProxy `hermes-agent`
  (tailscale LB dataplane), `*.taila659a.ts.net` hostnames, netpol (ssh/mdns
  from tailscale-system; dashboard/api/a2a from envoy-gateway-system), sops
  key.

Agent data PVCs (`hermes-agent-profiles-data`, `hermes-agent-skills-data`)
live under `clusters/nishir/base` — they are still mounted live by the
syncthing StatefulSet and must not be pruned.
