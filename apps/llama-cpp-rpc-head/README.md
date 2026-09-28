# llama-cpp-rpc-head

Dedicated llama.cpp deployment for `qwen/qwen3.8-flash`
(`Qwen3.8-Flash-Next-Q4_K_M`, 111 GiB): a single-replica `llama-server`
head (StatefulSet `llama-cpp-rpc-head`) that aggregates the RPC peer
`llama-cpp-rpc-worker` (`apps/llama-cpp-rpc-worker/`, one pod on the
other Halo node) via the preset key `rpc = 10.66.1.1:50052` — the
worker's static macvlan address, dialed over the cluster network.
Required `podAntiAffinity` keeps the head off the worker's node; the
pair placement is deterministic because the worker NAD is static IPAM.

## Layout

- `base/` — StatefulSet (per-replica 128Gi `longhorn-scratch` VCT
  `cache-huggingface`, power-of-2 floor above the model), Service,
  `AIServiceBackend` wrapping the Envoy `Backend`, VPA, VMServiceScrape,
  preset + prefetch ConfigMap generators (same ConfigMap names as
  `apps/llama-cpp`, same layout).
- `overlays/nishir/` — netpol admitting envoy on `http` plus vmagent
  scrapes only (RPC rides out; no return-path rule), and the
  `llama-cpp-rpc-head.i.shikanime.studio` hostnames + OIDC gate (own
  `llama-cpp-rpc-head` authelia client) on the HTTPRoutes that serve
  the router through the `llama-cpp` Gateway.
- The head container requests 60Gi: half the pair's 117.3 GiB resident
  set from the model ledger — 111.0 GiB of Q4_K_M weights plus the
  6.4 GiB q8_0 KV of the 262144-token context across two slots (12 of
  the 48 layers carry KV, `full_attention_interval = 4`). The layer
  split puts the other half on `llama-cpp-rpc-worker`, which requests
  the same.

The flash route rule's priority-0 backend is `Backend
llama-cpp-rpc-head`; this app's Flux Kustomization
(`apps-llama-cpp-rpc-head`) depends on `apps-llama-cpp-rpc-worker`
before rolling the head.
