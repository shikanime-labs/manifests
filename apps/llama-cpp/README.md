# llama-cpp

llama.cpp router as a LeaderWorkerSet `llama-cpp` spanning the two Strix Halo
MS-S1 nodes (`kushira`/`sashina`, label
`node.kubernetes.io/instance-type: minisforum-ms-s1`). `replicas: 1, size: 2`:
the leader runs `llama-server` and the worker runs `ggml-rpc-server` on the
other node (required `podAntiAffinity` on `kubernetes.io/hostname` keeps them on
separate nodes). The leader offloads layers to the rpc peer via `--rpc`,
aggregating both nodes' ~96 GiB GTT carve-outs (~192 GiB) so the 284B DeepSeek
V4 Flash floor fits; `--gpu-layers 999` offloads all layers to the iGPU. One
process serves both LLM and embedding models.

## Model loading (verified 2026-09-07)

Router mode lazy-loads models on demand: the preset sections map a route key to
an HF repo via the `hf` key (resolved against `--models-dir` as the download
cache), and the router spawns the per-model sub-server with `--hf-repo` only
when a request arrives — the sub-server then downloads the GGUF into the cache
and loads it. A `model = <local path>` key would point at a pre-provisioned
file instead, which is only useful with an init container that pre-pulls the
files. First request per model downloads its GGUF (~24 GB for the 27B); the
HF cache is an `emptyDir`, so pods re-download after restarts unless the
`models` volume is moved to a persistent hostPath. Preset sections:

- `deepseek/deepseek-v4-flash-0731` —
  `unsloth/DeepSeek-V4-Flash-0731-GGUF:UD-Q3_K_M`
- `z-ai/glm-5.3-flash` — `unsloth/GLM-5.3-Flash-GGUF:UD-IQ3_XXS`
- `qwen/qwen3.8-27b` — `unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL` (17.6 GB)
- `qwen/qwen3.8-flash` — `unsloth/Qwen3.8-Flash-Next-GGUF:UD-Q4_K_XL`
- `qwen/qwen3-embedding-8b` — `Qwen/Qwen3-Embedding-8B-GGUF:Q6_K` (6.2 GB)

Embedding note: the preset section name MUST match the gateway route key
exactly (`qwen/qwen3-embedding-8b`, as in `aigatewayroute.yaml`), because the
router looks the requested model up by section name; and
`LLAMA_ARG_EMBEDDINGS=true` is required — an empty value is not truthy in the
env parser, so the embedding sub-servers would start without the embedding
endpoint.

The Envoy AI Gateway (`apps/llama-cpp/base`) routes each model to this workload
as the `inference` backend at priority 0, then fails over to `nous` /
`openrouter`. `z-ai/glm-5.3-flash` also has a z-ai-only path when the local
floor is busy.

## GLM (Z.ai) via the Anthropic endpoint

The `inference` Gateway exposes LLM backends over mTLS. OpenAI-compatible
models are selected with the `x-ai-eg-model` header, but Z.ai GLM-5.3 is served
only on the Anthropic Messages protocol and is routed through the gateway's
Anthropic endpoint (`/anthropic/v1/messages`) instead of the OpenAI
`/v1/chat/completions` path.

The Anthropic endpoint selects the backend from the **body `model` field**, not
the `x-ai-eg-model` header (that header is only used on the OpenAI path).

```text
POST https://inference.taila659a.ts.net/anthropic/v1/messages
Headers:
  Content-Type: application/json
  anthropic-version: 2023-06-01
  (mTLS client cert)
Body:
  { "model": "z-ai/glm-5.3", "max_tokens": 64,
    "messages": [{ "role": "user", "content": "hi" }] }

=> 200 with an Anthropic message from glm-5.3
```

Auth is injected by `BackendSecurityPolicy z-ai` (`AnthropicAPIKey` →
`x-api-key`) against the hashed `z-ai-key-*` secret. The backend is
`AIServiceBackend z-ai` (schema `Anthropic`, prefix `api/anthropic/v1`).

## OpenAI-compatible models

```text
POST https://inference.taila659a.ts.net/v1/chat/completions
Headers: x-ai-eg-model: <provider/model>
Body: { "model": "<provider/model>", "messages": [...] }
```

Supported: `qwen/*`, `deepseek/deepseek-v4-flash`, `mistral/labs-leanstral-1-5`,
`z-ai/glm-5.3-flash`, `qwen/qwen3-embedding-8b`.

## Web UI

The llama.cpp built-in chat UI (served on the same :8080 HTTP port) is exposed
over the tailnet at `https://chat.i.shikanime.studio` via a dedicated BYOD
Envoy Gateway (`ui-gateway.yaml`: GatewayClass + EnvoyProxy + Gateway +
redirect route in the tailnet overlay), distinct from the API-key-locked
`inference` Gateway. TLS from the `studio-shikanime-i-chat` cert-manager
Certificate.
