# llama-cpp

Self-hosted llama.cpp inference for `nishir`: the small-model pool —
a `llama-server` router (StatefulSet `llama-cpp`, 2 replicas, one pod
per Strix Halo MS-S1 node `kushira`/`sashina` via
`feature.node.kubernetes.io/pci-0380_1002.present` affinity plus
required `podAntiAffinity` on `kubernetes.io/hostname`). Serves
`qwen/qwen3.8-27b` and `qwen/qwen3-embedding-8b`, both single-node
models: each loads entirely in its pod's pool (`--gpu-layers 999` via
preset `n-gpu-layers`), so no RPC peer and no macvlan lane are needed.
The dedicated 111 GiB flash model lives in `apps/llama-cpp-rpc-head/`,
which dials the RPC peer `apps/llama-cpp-rpc-worker/`.

## Layout

- `base/` — StatefulSet (2 replicas, per-replica 64Gi `longhorn-scratch`
  VCT `cache-huggingface`), Service, Envoy `Backend`/`AIServiceBackend`,
  HTTPRoutes, VPA, preset + prefetch ConfigMap generators.
- `components/monitoring/` — VMServiceScrape on `/metrics` (60s) for
  27b + embedding.
- `overlays/nishir/` — monitoring component, BYOD `llama-cpp` Gateway
  pieces (Certificate, Gateway, GatewayConfig, SecurityPolicy OIDC),
  gateway netpol, OIDC/env secrets.
- `overlays/nishir-tailnet/` — hostname appends + five-key label set.

## Model loading (prefetch init container)

An init container (`model-prefetch`, `ghcr.io/shikanime-labs/machines/
huggingface` image) runs `llama-cpp-prefetch/entrypoint.sh`: one
`hf download` per preset model, in parallel with per-PID error
propagation, into flat `/models/<Model>-<Quant>/` directories on the
per-replica 64Gi `longhorn-scratch` VCT `cache-huggingface` (~2x the
~33 GiB of prefetched models). The
volume is mounted a
second time at the image's native HF cache path
(`/home/huggingface/.cache/huggingface`) because the init container root
filesystem is read-only. The serving container mounts the same PVC at
`/models` and at `/home/llama.cpp/.cache/huggingface`.

The preset (ConfigMap `llama-cpp-models-preset`, mounted at
`/etc/llama-cpp/preset`) maps route keys to local `model =` paths. The
preset refs must stay 1:1 with the prefetch script's
`--include`/`--local-dir` pairs; review enforces this. The router serves
one resident model (`LLAMA_ARG_MODELS_MAX=1`, autoload on): the first
request targeting a model loads it, and requesting another evicts it. The
DFlash2 drafter for the 27B is prefetched alongside its target and
referenced via `model-draft =`.

Preset sections and tuning keys:

- `qwen/qwen3.8-27b` → `Qwen3.8-27B-UD-Q6_K` (unsloth): dflash
  speculative decoding (`spec-type = draft-dflash`, drafter
  `Qwen3.8-27B-DFlash2-Q8_0`, `spec-draft-n-max = 4`),
  `ubatch-size = 1024` / `batch-size = 4096`, `cache-reuse = 512`,
  `load-mode = dio`.
- `qwen/qwen3.8-flash` → served by the dedicated `llama-cpp-rpc-head`
  app (see `apps/llama-cpp-rpc-head/README.md`), not this pool.
- `qwen/qwen3-embedding-8b` → `Qwen3-Embedding-8B-Q6_K`:
  `embeddings = true`.

Route-key rules:

- The preset section name MUST match the `x-ai-eg-model` route key
  exactly (`aigatewayroute.yaml`); the router looks the requested model
  up by section name.
- `embeddings = true` is per-model on purpose: pod-wide
  `LLAMA_ARG_EMBEDDINGS=true` restricts every child to embedding-only
  mode and aborts generative models at first decode; without the
  per-model key `/v1/embeddings` returns 501.
- `load-mode = dio` roughly halves cold load on the warm cache pair.
  `ubatch/batch` bypasses the router-wide embeddings clamp that forces
  `n_batch` to `n_ubatch` on every child.
- Leader env fixes flash attention on with a q8_0 KV cache
  (`LLAMA_ARG_FLASH_ATTN=on`, `LLAMA_ARG_CACHE_TYPE_K/V=q8_0`).

## GPU backend

The x86_64 image builds against ROCm: new-architecture graphs abort at
first decode on RADV
([ggml-org/llama.cpp#29028][radv-abort]);
the fleet flip is
[shikanime-labs/machines#1357][m1357].

[radv-abort]: https://github.com/ggml-org/llama.cpp/issues/29028
[m1357]: https://github.com/shikanime-labs/machines/pull/1357

## Envoy AI Gateway

`base/` carries the Envoy AI Gateway objects. `Backend llama-cpp` points
at the router Service (`llama-cpp.shikanime.svc.cluster.local:9931`).
`AIGatewayRoute default` maps each route key to that backend at
`priority: 0` and fails over to `nous` / `openrouter`; route timeouts are
`0s` on the AIGatewayRoute and `600s` on the HTTPRoutes (long
generations).

The `inference` Gateway (overlay `nishir/`) terminates TLS for
`inference.i.shikanime.studio` and stacks two auth layers: mTLS client
certificates (`ClientTrafficPolicy inference`) and API keys
(`SecurityPolicy inference-apikey`, Secret `inference-key`, headers
sanitized before upstream). The same ClientTrafficPolicy raises the
response buffer to 50Mi so embedding vectors clear the ext-proc 32KiB
default.

Remote providers: `nous` and `openrouter` are OpenAI-schema
(`AIServiceBackend`; OpenRouter needs `prefix: api/v1`), `z-ai` is
Anthropic-schema (`prefix: api/anthropic/v1`), and `z-ai-openai` targets
the CODING-PLAN endpoint (`prefix: api/coding/paas/v4`). Provider keys
come from `BackendSecurityPolicy` objects bound to the generated
`*-key` Secrets.

### GLM (Z.ai)

The OpenAI-compatible endpoint selects the backend with the
`x-ai-eg-model` header; the Anthropic endpoint (`/anthropic/v1/messages`)
selects it from the body `model` field instead.

```text
POST https://inference.i.shikanime.studio/anthropic/v1/messages
Headers:
  Content-Type: application/json
  anthropic-version: 2023-06-01
  (mTLS client cert)
Body:
  { "model": "z-ai/glm-5.3", "max_tokens": 64,
    "messages": [{ "role": "user", "content": "hi" }] }
```

### OpenAI-compatible models

```text
POST https://inference.i.shikanime.studio/v1/chat/completions
Headers: x-ai-eg-model: <provider/model>
Body: { "model": "<provider/model>", "messages": [...] }
```

Served locally: `qwen/qwen3.8-27b`, `qwen/qwen3-embedding-8b`. The
remaining routes go to remote providers only: `qwen/qwen3.8-flash` to
`apps/llama-cpp-rpc-head`, `z-ai/glm-5.3-flash` to the Z.ai
OpenAI-compatible endpoint, `z-ai/glm-5.3` to the Anthropic endpoint,
`mistral/labs-leanstral-1-5` to Mistral, and the catch-all to
nous/openrouter.

## Web UI

The llama.cpp built-in chat UI (same `:9931` port) is exposed through the
dedicated BYOD `llama-cpp` Gateway (`GatewayClass` + `EnvoyProxy` +
`Gateway` in `overlays/nishir-tailnet/`, tailscale loadBalancerClass) at
`chat.i.shikanime.studio` / `chat.taila659a.ts.net`, behind authelia OIDC
(`SecurityPolicy llama-cpp-oidc-client`) with TLS from the
`studio-shikanime-i-chat` Certificate. Browser `/v1` calls are split onto
the `llama-cpp-api` HTTPRoute (API key + CORS, with the overlay setting
`LLAMA_ARG_CORS_ORIGINS=https://inference.i.shikanime.studio`) so they
get 401 JSON with CORS headers instead of an OIDC redirect.

## Observability and scaling

- `components/monitoring/` exposes the router `:9931/metrics` to vmagent
  (`VMServiceScrape llama-cpp`).
- `vpa.yaml` targets the StatefulSet (`updateMode: InPlace`, 32Gi memory
  floor on the router container — above the 27B resident working set).
