#!/bin/sh
set -eu
rc=0
hf download lmstudio-community/Qwen3.8-Flash-Next-GGUF \
  --include 'Qwen3.8-Flash-Next-Q4_K_M-*' \
  --local-dir /models/Qwen3.8-Flash-Next-Q4_K_M &
wait "$!" || rc=1
exit "$rc"
