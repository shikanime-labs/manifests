#!/bin/sh
set -eu
rc=0
hf download unsloth/Qwen3.8-27B-GGUF \
  --include 'Qwen3.8-27B-UD-Q6_K.gguf' \
  --local-dir /models/Qwen3.8-27B-UD-Q6_K &
wait "$!" || rc=1
hf download incoai/Qwen3.8-27B-DFlash2-GGUF \
  --include 'Qwen3.8-27B-DFlash2-Q8_0.gguf' \
  --local-dir /models/Qwen3.8-27B-DFlash2-Q8_0 &
wait "$!" || rc=1
hf download Qwen/Qwen3-Embedding-8B-GGUF \
  --include 'Qwen3-Embedding-8B-Q6_K.gguf' \
  --local-dir /models/Qwen3-Embedding-8B-Q6_K &
wait "$!" || rc=1
exit "$rc"
