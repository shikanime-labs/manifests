# llama-cpp

Local GGUF inference floors for the inference app: llama.cpp servers pinned to
AMD GPU nodes, each serving one model over HTTP :8080 (plus gRPC :50052 where an
RPC shard splits the model). The inference AIGatewayRoute drains them first as
`priority: 0` local backends before failing over to remote providers.

## Members

- `deepseek-flash/` — unsloth/DeepSeek-V4-Flash-0731-GGUF (Q4_K_M), with the
  model sharded to `deepseek-flash-rpc` via `--rpc`.
- `deepseek-flash-rpc/` — llama.cpp `--rpc-server` shard for deepseek-flash on
  :50052.
- `qwen-27b/` — unsloth/Qwen3.8-27B-GGUF (Q8_0, vision mmproj), 32k context.
- `qwen-embedding/` — unsloth/Qwen3-Embedding-4B-GGUF (Q8_0) in `--embeddings`
  mode, 40k context.
