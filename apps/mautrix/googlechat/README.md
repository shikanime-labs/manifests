# googlechat

Mautrix bridge linking Matrix to Google Chat, running
dock.mau.dev/mautrix/googlechat as a single-replica StatefulSet. Serves
the appservice API on :29320 with live/ready probes under /_matrix/mau/*
and exposes /metrics on :9100. Config, double-puppet, and registration
files are SOPS-encrypted secrets mounted read-only into /data; the same
secrets are projected into synapse's startup-config so the bridge
registers as an appservice.

## Layout

- `base/` — sts.yaml, svc.yaml (http :29320, metrics :9100),
  netpol.yaml, pvc.yaml, vpa.yaml.
- `overlays/nishir/` — PVC patch.
- `overlays/nishir-tailnet/` — config/doublepuppet/registration
  secretGenerator, tailscale Ingress `matrix-googlechat`, netpol for
  tailscale-system, VMServiceScrape on the metrics port.
