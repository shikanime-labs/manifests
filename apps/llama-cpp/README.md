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

Models are pulled once at startup by the leader container (`llama-cli -hf` of
the best-fit unsloth quants, flattened into the flat names the preset
references) into an `emptyDir` at `/models`. Router mode serves the local floors
(shared context window `-c 32768`, `--models-max 5`):

- `deepseek/deepseek-v4-flash-0731` —
  `unsloth/DeepSeek-V4-Flash-0731-GGUF:UD-Q3_K_M`
- `z-ai/glm-5.3-flash` — `unsloth/GLM-5.3-Flash-GGUF:UD-IQ3_XXS`
- `qwen/qwen3.8-27b` — `unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL`
- `qwen/qwen3.8-flash` — `unsloth/Qwen3.8-Flash-Next-GGUF:UD-Q4_K_XL`
- `qwen/qwen3-embedding-8b` — `unsloth/Qwen3-Embedding-8B-GGUF:UD-Q5_K_XL`

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

Auth is injected by `BackendSecurityPolicy z-ai-key` (`AnthropicAPIKey` →
`x-api-key`) against the hashed `inference-z-ai-*` secret. The backend is
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
over the tailnet at `https://llama-cpp.i.shikanime.studio` via a dedicated BYOD
Envoy Gateway (`ui-gatewayclass`/`ui-gateway`/`ui-envoyproxy` in the tailnet
overlay), distinct from the API-key-locked `inference` Gateway. TLS from the
`studio-shikanime-i-llama-cpp` cert-manager Certificate.
