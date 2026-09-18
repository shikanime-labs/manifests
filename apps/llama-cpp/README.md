# llama-cpp

llama.cpp router as a LeaderWorkerSet `llama-cpp` spanning the two Strix Halo
MS-S1 nodes (`kushira`/`sashina`, label
`node.kubernetes.io/instance-type: minisforum-ms-s1`). `replicas: 2`:
the leader runs `llama-server` and the worker runs `ggml-rpc-server` on the
other node (required `podAntiAffinity` on `kubernetes.io/hostname` keeps them on
separate nodes). The leader offloads layers to the rpc peer via `--rpc`,
aggregating both nodes' ~96 GiB GTT carve-outs (~192 GiB) so the 284B DeepSeek
V4 Flash floor fits; `--gpu-layers 999` offloads all layers to the iGPU. One
process serves both LLM and embedding models.

## Model loading

Router mode lazy-loads models on demand: the preset sections map a route key to
an HF repo via the `hf` key (resolved against `--models-dir` as the download
cache), and the router spawns the per-model sub-server with `--hf-repo` only
when a request arrives — the sub-server then downloads the GGUF into the cache
and loads it. A `model = <local path>` key would point at a pre-provisioned
file instead, which is only useful with an init container that pre-pulls the
files. First request per model downloads its GGUF (~24 GB for the 27B); the
HF cache is an `emptyDir`, so pods re-download after restarts unless the
`models` volume is moved to a persistent hostPath. Preset sections:

- `deepseek/deepseek-v4-flash` —
  `lmstudio-community/DeepSeek-V4-Flash-0731-GGUF:MXFP4`
  (`rpc` = both worker pods, `fit = off`)
- `qwen/qwen3.8-27b` — `unsloth/Qwen3.8-27B-GGUF:UD-Q6_K`
  (dflash draft `incoai/Qwen3.8-27B-DFlash2-GGUF:Q8_0`, `cache-reuse = 512`)
- `qwen/qwen3.8-flash` — `unsloth/Qwen3.8-Flash-Next-GGUF:UD-Q4_K_XL`
  (`rpc` = both worker pods, `no-warmup = true`)
- `qwen/qwen3-embedding-8b` — `Qwen/Qwen3-Embedding-8B-GGUF:Q6_K` (6.2 GB)

## GPU backend

The x86_64 image builds against ROCm. qwen4exp and deepseek-v4 abort at first
decode on RADV (upstream
[ggml-org/llama.cpp#29028](https://github.com/ggml-org/llama.cpp/issues/29028));
qwen3.8-27b and the embedding model were unaffected there too. The fleet flip
to ROCm is
[shikanime-labs/machines#1357][m1357]
(qwen4exp decodes on ROCm; deepseek-v4 failed at model load in the kushira
probe — pending a root cause). The two
issue 2385 experiment lines — deepseek `n-gpu-layers = 48`, flash Q3 quant —
are reverted to 999/Q4 in this change.

Embedding note: the preset section name MUST match the gateway route key
exactly (`qwen/qwen3-embedding-8b`, as in `aigatewayroute.yaml`), because the
router looks the requested model up by section name; and the section carries
`embeddings = true` — without it `/v1/embeddings` returns 501. The flag is
per-model on purpose: pod-wide `LLAMA_ARG_EMBEDDINGS=true` restricts every
child to embedding-only mode and aborts generative models at first decode.

The Envoy AI Gateway (`apps/llama-cpp/base`) routes each model to this workload
as the `inference` backend at priority 0, then fails over to `nous` /
`openrouter`.

## GLM (Z.ai) via the Anthropic endpoint

The `inference` Gateway exposes LLM backends over mTLS. OpenAI-compatible
models are selected with the `x-ai-eg-model` header, but Z.ai GLM-5.3 is served
only on the Anthropic Messages protocol and is routed through the gateway's
Anthropic endpoint (`/anthropic/v1/messages`) instead of the OpenAI
`/v1/chat/completions` path.

The Anthropic endpoint selects the backend from the **body `model` field**, not
the `x-ai-eg-model` header (that header is only used on the OpenAI path).

```text
POST https://inference.i.shikanime.studio/anthropic/v1/messages
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
POST https://inference.i.shikanime.studio/v1/chat/completions
Headers: x-ai-eg-model: <provider/model>
Body: { "model": "<provider/model>", "messages": [...] }
```

Supported: `qwen/qwen3.8-27b`, `qwen/qwen3.8-flash`,
`deepseek/deepseek-v4-flash`, and `qwen/qwen3-embedding-8b`, all served
locally. The other advertised models fail over to remote providers.

## Web UI

The llama.cpp built-in chat UI (served on the same :9931 HTTP port) is exposed
over the tailnet at `https://chat.i.shikanime.studio` via a dedicated BYOD
Envoy Gateway (`ui-gateway.yaml`: GatewayClass + EnvoyProxy + Gateway +
redirect route in the tailnet overlay), distinct from the API-key-locked
`inference` Gateway. TLS from the `studio-shikanime-i-chat` cert-manager
Certificate.

[m1357]: https://github.com/shikanime-labs/machines/pull/1357
