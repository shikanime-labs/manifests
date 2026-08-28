# meta

Mautrix bridge linking Matrix to Meta Messenger (WhatsApp and
Instagram), running dock.mau.dev/mautrix/meta as a single-replica
StatefulSet. Serves the appservice API on :29319 with live/ready probes
under /_matrix/mau/*. Config, double-puppet, and registration files are
SOPS-encrypted secrets mounted read-only into /data; the same secrets
are projected into synapse's startup-config so the bridge registers as
an appservice.

## Layout

- `base/` — sts.yaml, svc.yaml (http :29319), netpol.yaml (synapse and
  synapse-proxy only), pvc.yaml, vpa.yaml.
- `overlays/nishir/` — PVC patch.
- `overlays/nishir-tailnet/` — config/doublepuppet/registration
  secretGenerator, tailscale Ingress `matrix-meta`, netpol for
  tailscale-system.
