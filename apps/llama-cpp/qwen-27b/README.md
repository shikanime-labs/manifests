# qwen-27b

llama.cpp serving unsloth/Qwen3.8-27B-GGUF (Q8_0, with the mmproj vision
projector) on an AMD GPU node, HTTP :8080 with a 32k context. Local floor for
the inference app's `qwen-27b.shikanime.svc.cluster.local` backend at
priority 0.

## Layout

- `base/` — StatefulSet, Service (:8080), VPA, default-deny NetworkPolicy
  (ingress + egress).
- `components/monitoring/` — VMServiceScrape on /metrics.
- `overlays/nishir/` — namespace, monitoring component.
- `overlays/nishir-tailnet/` — Tailscale Ingress, netpol patch admitting
  tailscale-system (http) and vmagent (metrics), llm-inference labels.
