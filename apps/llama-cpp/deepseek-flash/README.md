# deepseek-flash

llama.cpp serving unsloth/DeepSeek-V4-Flash-0731-GGUF (Q4_K_M) on an AMD GPU
node (`feature.node.kubernetes.io/amd-gpu`), HTTP :8080. It is the inference
app's `deepseek-flash.shikanime.svc.cluster.local` local floor (priority 0);
an RPC :50052 port connects to the `deepseek-flash-rpc` shard
(`--rpc http://deepseek-flash-rpc-server:50052`). 8k context, flash
attention, q8_0 KV cache, HF models cached in an emptyDir.

## Layout

- `base/` — StatefulSet, Service (:8080 http, :50052 rpc), VPA, and two
  NetworkPolicies scoping RPC access between the main server and its shard.
- `components/monitoring/` — VMServiceScrape on /metrics.
- `overlays/nishir/` — namespace, monitoring component.
- `overlays/nishir-tailnet/` — Tailscale Ingress (HTTPS defaultBackend),
  netpol patch admitting tailscale-system (http) and vmagent (metrics),
  llm-inference labels.
