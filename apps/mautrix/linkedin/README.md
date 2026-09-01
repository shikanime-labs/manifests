# linkedin

Mautrix bridge linking Matrix to LinkedIn, running dock.mau.dev/mautrix/linkedin
as a single-replica StatefulSet. Serves the appservice API on :29341 with
live/ready probes under /_matrix/mau/*. Config, double-puppet, and registration
files are SOPS-encrypted secrets mounted read-only into /data; the same secrets
are projected into synapse's startup-config so the bridge registers as an
appservice.

## Layout

- `base/` — sts.yaml, svc.yaml (http :29341), netpol.yaml (synapse only),
  pvc.yaml, vpa.yaml.
- `overlays/nishir/` — PVC patch.
- `overlays/nishir-tailnet/` — config/doublepuppet/registration secretGenerator,
  tailscale Ingress `matrix-linkedin`, netpol for tailscale-system.
