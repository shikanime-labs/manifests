# catbox

KubeVirt VM (ghcr.io/shikanime-labs/machines/catbox:latest NixOS qcow2 as a
containerDisk, no CDI) exposing SSH :22 and mDNS :5353/UDP over a LoadBalancer
Service. Boots on amd64 nodes with a 64Gi `catbox-workspaces` PVC; the netpol
admits only tailscale-system, and the tailnet overlay publishes the Service
through the Tailscale operator.

## Layout

- `base/` — VirtualMachine (runStrategy Always), Service (:22 tcp, :5353 udp),
  workspaces PVC, netpol (tailscale-system only).
- `overlays/nishir/` — namespace, PVC patch.
- `overlays/nishir-tailnet/` — tailscale.com annotations and
  `loadBalancerClass: tailscale`, labels (part-of telsha-workstation).
