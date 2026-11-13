# automata

KubeVirt VM running the hermes-agent natively via the upstream NixOS module
(see shikanime-labs/machines, hosts/automata), published as
`ghcr.io/shikanime-labs/machines/automata:latest` containerDisk (NixOS qcow2,
no CDI). Boots on amd64 nodes with a 64Gi `automata-workspaces` PVC.

All exposure rides the `automata` Gateway: dashboard :9119, api-server
:8642, a2a :9900 (HTTPRoute), ssh :22 (TCPRoute), mdns :5353/UDP (UDPRoute);
the gateway's envoyService adopts the `automata` Service and is the single
tailscale device (`automata-gateway`). webhook :8644 additionally surfaces
through the envoy-gateway funnel Ingress (`automata-webhook.taila659a.ts.net`).

## Layout

- `base/` — VirtualMachine (runStrategy Always), ClusterIP Service (:22 tcp,
  :5353 udp, :9119, :8642, :9900, :8644), workspaces PVC, HTTPRoutes
  (`automata-dashboard` with a `/webhooks` prefix route to the webhook
  receiver, `automata-api-server`, `automata-a2a`) each with a 301
  redirect twin on the http listener, TCPRoute/TCPRoute-ssh/UDPRoute for the
  non-HTTP ports.
- `overlays/nishir/` — namespace, per-hostname certs, Gateway `automata`
  (http/https + ssh/a2a/mdns listeners, `*.i.shikanime.studio`).
- `overlays/nishir-tailnet/` — GatewayClass/EnvoyProxy `automata`
  (tailscale LB dataplane, envoyService `automata`, hostname
  `automata-gateway`), route-to-listener patches, `*.taila659a.ts.net`
  hostnames, netpol (all six ports from
  envoy-gateway-system), sops key.

Agent data PVCs (`hermes-agent-profiles-data`, `hermes-agent-skills-data`)
live under `clusters/nishir/base` — they are still mounted live by the
syncthing StatefulSet and must not be pruned.
