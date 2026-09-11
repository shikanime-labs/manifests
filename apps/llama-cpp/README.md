# llama-cpp inference fleet

Four lanes, one per app directory (each with its own Flux Kustomization in
`clusters/nishir/overlays/tailnet/ks.yaml`):

- `../llama-cpp` — local-only `llama-server` for single-GPU models (qwen
  family, embeddings). No RPC peer: ggml layer-split would otherwise spread
  the weights across nodes (manifests#2322). MTP draft enabled on qwen3.8-27b.
- `../llama-cpp-leader` — RPC-topology `llama-server` for models exceeding one
  MS-S1 node (GLM-5.3-flash, DeepSeek V4 Flash). Composes its iGPU with one
  `ggml-rpc-server` peer.
- `../llama-cpp-worker` — the `ggml-rpc-server` peer.
- `../inference` — Envoy AI Gateway tier: `inference.i` listener, TLS, OIDC,
  provider keys, and per-model steering between the two server lanes in
  `base/aigatewayroute.yaml`.

The two servers carry mutual required anti-affinity and are never
co-scheduled. Per-lane model catalogs live in each lane's
`models-preset.ini`; model → backend priority lives in the inference app.
