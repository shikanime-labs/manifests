# qwen-embedding

llama.cpp in `--embeddings` mode serving unsloth/Qwen3-Embedding-4B-GGUF (Q8_0)
on an AMD GPU node, HTTP :8080 with a 40k context. Embeddings floor for the
inference app.

## Layout

- `base/` — StatefulSet, Service (:8080), VPA, default-deny NetworkPolicy
  (ingress + egress).
- `components/monitoring/` — VMServiceScrape on /metrics.
- `overlays/nishir/` — namespace, monitoring component.
- `overlays/nishir-tailnet/` — Tailscale Ingress, netpol patch admitting
  tailscale-system (http) and vmagent (metrics), llm-inference labels.
