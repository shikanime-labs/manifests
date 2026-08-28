# deepseek-flash-rpc

llama.cpp `--rpc-server` shard for deepseek-flash: the same
unsloth/DeepSeek-V4-Flash-0731-GGUF (Q4_K_M) model, listening on gRPC :50052 so
the `deepseek-flash` StatefulSet can split layers across both pods. Pinned to an
AMD GPU node with the same flash-attention/q8_0 cache tuning.

## Layout

- `base/` — StatefulSet + Service (:50052 rpc), NetworkPolicy admitting only the
  deepseek-flash pod.
- `overlays/nishir-tailnet/` — namespace, llm-inference labels (part-of
  nishir-inference).
