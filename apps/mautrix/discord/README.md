# discord

Mautrix bridge linking Matrix to Discord, running dock.mau.dev/mautrix/discord
as a single-replica StatefulSet. Serves the appservice API on :29334 with
live/ready probes under /_matrix/mau/*. Config, double-puppet, and registration
files are SOPS-encrypted secrets mounted read-only into /data; the same secrets
are projected into synapse's startup-config so the bridge registers as an
appservice. An extra `matrix-discord-media` Ingress lets synapse-proxy route
direct Discord media downloads to the bridge.

## Layout

- `base/` — sts.yaml, svc.yaml (http :29334), netpol.yaml (synapse and
  synapse-proxy only), pvc.yaml, vpa.yaml.
- `overlays/nishir/` — PVC patch.
- `overlays/nishir-tailnet/` — config/doublepuppet/registration secretGenerator,
  tailscale Ingresses `matrix-discord` and `matrix-discord-media`, netpol for
  tailscale-system.
