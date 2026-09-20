#!/bin/sh
set -eu

pids=""

hf download lmstudio-community/DeepSeek-V4-Flash-0731-GGUF \
  --include 'DeepSeek-V4-Flash-0731-MXFP4-*' \
  --local-dir /models/DeepSeek-V4-Flash-0731-MXFP4 &
pids="$pids $!"

hf download unsloth/Qwen3.8-27B-GGUF \
  --include 'Qwen3.8-27B-UD-Q6_K.gguf' \
  --local-dir /models/Qwen3.8-27B-UD-Q6_K &
pids="$pids $!"

hf download incoai/Qwen3.8-27B-DFlash2-GGUF \
  --include 'Qwen3.8-27B-DFlash2-Q8_0.gguf' \
  --local-dir /models/Qwen3.8-27B-DFlash2-Q8_0 &
pids="$pids $!"

hf download lmstudio-community/Qwen3.8-Flash-Next-GGUF \
  --include 'Qwen3.8-Flash-Next-Q4_K_M-*' \
  --local-dir /models/Qwen3.8-Flash-Next-Q4_K_M &
pids="$pids $!"

hf download Qwen/Qwen3-Embedding-8B-GGUF \
  --include 'Qwen3-Embedding-8B-Q6_K.gguf' \
  --local-dir /models/Qwen3-Embedding-8B-Q6_K &
pids="$pids $!"

rc=0
for pid in $pids; do
  wait "$pid" || rc=1
done
exit "$rc"
