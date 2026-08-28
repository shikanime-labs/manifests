# llama-cpp

Single llama.cpp router (LeaderWorkerSet `llama-cpp`) per Strix Halo MS-S1 node
(`kushira`/`sashina`, label
`node.kubernetes.io/instance-type: minisforum-ms-s1`), two replicas spread by
`podAntiAffinity` on `kubernetes.io/hostname`. One process serves both LLM and
embedding models from a shared 120Gi memory pool, so llama.cpp LRU-evicts across
all floors instead of holding two fixed-budget pods (the old 120Gi LLM + 24Gi
embed split couldn't even co-schedule on a 128Gi node).

Models are pulled once at startup by an init container (`llama-cli -hf` of the
best-fit unsloth quants, flattened into the flat names the preset references)
into an `emptyDir` at `/models`. Router mode serves the local floors (shared
context window `-c 32768`, `--models-max 5`):

- `deepseek/deepseek-v4-flash-0731` —
  `unsloth/DeepSeek-V4-Flash-0731-GGUF:UD-Q3_K_M`
- `z-ai/glm-5.3-flash` — `unsloth/GLM-5.3-Flash-GGUF:UD-IQ3_XXS`
- `qwen/qwen3.8-27b` — `unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL`
- `qwen/qwen3.8-flash` — `unsloth/Qwen3.8-Flash-Next-GGUF:UD-Q4_K_XL`
- `embeddings/qwen-embed` — `unsloth/Qwen3-Embedding-8B-GGUF:UD-Q5_K_XL`

The Envoy AI Gateway (`apps/llama-cpp/base`) routes each model to this workload
as the `inference` backend at priority 0, then fails over to `nous` /
`openrouter`. `z-ai/glm-5.3-flash` also has a zai-only path when the local floor
is busy.
