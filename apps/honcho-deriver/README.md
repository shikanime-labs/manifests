# honcho-deriver

Standalone Honcho deriver worker: drains the deriver queue and derives
per-peer observations, summaries, and working representations. Runs
upstream's `python -m src.deriver` from the same digest-pinned image as
honcho, against the same postgres. A separate app so its pods carry
`app.kubernetes.io/instance: honcho-deriver` and can never be selected
by the honcho Service (the endpoint black-hole incident in #2200).

## Layout

- `base/` — Deployment (no ports), VPA, deny-ingress netpol.
- `overlays/nishir/` — namespace, LLM key secret generator (stable name;
  DB credentials come from the stable `honcho-postgres` secret).
- `overlays/nishir-tailnet/` — namespace + workload labels + config.toml.
