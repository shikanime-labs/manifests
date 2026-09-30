# halogen-flash

[peonist-ai halogen-flash-server](https://github.com/peonist-ai/halogen-flash-server)
serving `qwen/qwen3.8-flash` (Qwen3.8-Flash-Next) as a single-node Strix Halo
replacement for the llama.cpp RPC pair. Adopted from the live evaluation in
[shikanime-labs/manifests#2701](https://github.com/shikanime-labs/manifests/issues/2701):
10-20x prefill, 3x decode, 13x lower TTFT at 32K depth versus the RPC baseline.

Exclusive: the w4b checkpoint pins ~68 GiB locked RAM plus KV pool on one
128 GB Halo node — the pod anti-affinity keeps it off the llama-cpp-rpc-head
node. Land the cutover (route `qwen/qwen3.8-flash` here, scale the RPC pair
down) as a separate change after soak.

Weights prefetch into a local-path PVC (`qwen38-flash-next-w4b.hgn` 115.5 GiB

- mtp sidecar + tokenizer). No `HALOGEN_DOWNLOAD`: the engine container makes
no outbound connections.

## Layout

- `base/` — StatefulSet (2 replicas, one pod per Strix Halo node via
  `podAntiAffinity` on `kubernetes.io/hostname`), Service + headless
  Service, Envoy `Backend`/`AIServiceBackend`, VPA.
- `components/monitoring/` — VMServiceScrape on `/metrics` (60s), a
  `HalogenFlashDown` VMRule, vmagent netpol ingress.
- `overlays/nishir/` — monitoring component, gateway netpol.
- `overlays/nishir-tailnet/` — hostname appends + five-key label set.

## Routing

Each replica holds its own prompt cache, and an agent conversation is one
long prompt, so a turn that lands on the other replica re-reads the whole
history. The gateway hash-rings the pod endpoints on `agent-session-id`
(`backendtrafficpolicy.yaml`): every turn carrying the header stays on one
replica, requests without it balance normally. hermes ships the value per
conversation (`session_affinity_header`).

The engine serves Prometheus `llamacpp:*` series on its published API port
(`:8731/metrics`); the engine port `:8730` is loopback-only.
