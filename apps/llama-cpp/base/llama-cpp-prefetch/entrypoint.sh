#!/bin/sh
set -eu
rc=0
mkdir -p /models/Qwen3.8-27B-UD-Q6_K/MTP
pids=""
add_dl() {
  hf download "$@" &
  pids="$pids $!"
}
add_dl unsloth/Qwen3.8-27B-GGUF \
  --include 'Qwen3.8-27B-UD-Q6_K.gguf' \
  --local-dir /models/Qwen3.8-27B-UD-Q6_K
add_dl unsloth/Qwen3.8-27B-GGUF \
  --include 'MTP/mtp-Qwen3.8-27B-Q4_0.gguf' \
  --local-dir /models/Qwen3.8-27B-UD-Q6_K
add_dl Qwen/Qwen3-Embedding-8B-GGUF \
  --include 'Qwen3-Embedding-8B-Q6_K.gguf' \
  --local-dir /models/Qwen3-Embedding-8B-Q6_K
for pid in $pids; do
  wait "$pid" || rc=1
done
exit "$rc"
