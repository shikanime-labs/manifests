# mautrix

Matrix bridge suite (dock.mau.dev/mautrix/*) for the shikanime office Matrix
deployment. Each bridge is its own base/overlays app: a single-replica
StatefulSet serving the appservice API on a per-bridge port, with SOPS-encrypted
config/doublepuppet/registration secrets and a tailnet Ingress per bridge. The
same registration and doublepuppet secrets are projected into synapse's
startup-config, so every bridge registers as an appservice on boot. Members:

- `discord` — Discord (port 29334, media Ingress via synapse-proxy)
- `googlechat` — Google Chat (port 29320, metrics + VMServiceScrape)
- `linkedin` — LinkedIn (port 29341)
- `meta` — Meta Messenger, WhatsApp and Instagram (port 29319)
- `signal` — Signal (port 29328)
- `slack` — Slack (port 29335)
- `twitter` — Twitter/X (port 29327)
- `whatsapp` — WhatsApp (port 29318)

All bridges expose their API at `matrix-<name>.taila659a.ts.net`.
