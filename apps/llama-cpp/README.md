# llama-cpp (nishir inference)

The `inference` Gateway exposes LLM backends via Envoy AI Gateway. Clients
authenticate with mTLS client certs and select a backend with the
`x-ai-eg-model` header on the OpenAI endpoint.

## GLM (Z.ai) via the Anthropic endpoint

Z.ai GLM-5.3 is served only on the Anthropic Messages protocol, so it is
routed through the gateway's Anthropic endpoint (`/anthropic/v1/messages`)
rather than the OpenAI `/v1/chat/completions` path.

The Anthropic endpoint selects the backend from the **body `model` field**,
not the `x-ai-eg-model` header (that header is only used on the OpenAI path).

```
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

```
POST https://inference.taila659a.ts.net/v1/chat/completions
Headers: x-ai-eg-model: <provider/model>
Body: { "model": "<provider/model>", "messages": [...] }
```

Supported: `qwen/*`, `deepseek/deepseek-v4-flash`, `mistral/labs-leanstral-1-5`,
`z-ai/glm-5.3-flash`, `qwen/qwen3-embedding-8b`.
