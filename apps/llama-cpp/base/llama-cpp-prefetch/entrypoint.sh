#!/bin/sh
set -eu
rc=0
hf download Qwen/Qwen3-Embedding-8B-GGUF \
  --include 'Qwen3-Embedding-8B-Q6_K.gguf' \
  --local-dir /models/Qwen3-Embedding-8B-Q6_K &
wait "$!" || rc=1
exit "$rc"
