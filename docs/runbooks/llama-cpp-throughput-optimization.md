# llama.cpp local-floor throughput optimization

<!-- owner: shikanime studio | zone: internal | purpose: measure and lift qwen3.8-27b decode t/s on the MS-S1 RPC pair -->

## Problem

`qwen/qwen3.8-27b` decoded at ~10.4 t/s on the llama-cpp router while the same
model reaches 24-36 t/s on a single Strix Halo with MTP speculative decoding
(issue #2309). This runbook records the measurement methodology and the
validated tuning path (10.4 → 17.5 t/s, PR #2312).

## Architecture under test

- `sts/llama-cpp` (leader, CPU-only `llama-server` in router mode, port 8080)
- `sts/llama-cpp-rpc` (2 × `ggml-rpc-server`, one per MS-S1, `/dev/kfd` + `/dev/dri`)
- Leader dials both workers via `LLAMA_ARG_RPC` (router-global env).
- Inter-node link: bonded 10 GbE (`eth0 speed=10000` inside the rpc pods), ~65 us
  RTT; NOT the 2.5 GbE onboard the strategy issue #1804 assumed.

## Methodology

### 1. Baseline on production, server-side numbers only

Port-forward and read `print_timing` from the leader log — client wall time is
polluted by cold model load:

```bash
kubectl port-forward -n shikanime pod/llama-cpp-0 18080:8080 &
KEY=$(kubectl get secret -n shikanime llama-cpp-key-<hash> \
  -o jsonpath='{.data.apiKey}' | base64 -d)
curl -H "Authorization: Bearer $KEY" \
  http://127.0.0.1:18080/v1/chat/completions \
  -d '{"model":"qwen/qwen3.8-27b","messages":[...],"max_tokens":256}'
kubectl logs -n shikanime llama-cpp-0 | grep 'print_timing.*eval time' | tail
```

Discard the first request per model (cold load; a transient HF fetch of
`mmproj-BF16.gguf` can 500 once and the router retries). Report
`eval time = X ms / N tokens` lines only.

### 2. Shadow StatefulSet for experiments — never patch prod in place

Clone the leader STS, swap the preset ConfigMap, pin the node, drop the PVC to
emptyDir (models re-download in ~6 min; RPC workers keep tensor shards in
`/cache/rpc` so re-loads take ~1 min):

```bash
kubectl get sts -n shikanime llama-cpp -o json | python3 - <<'EOF'
# name -> llama-cpp-bench, strip uid/resourceVersion, replace models-preset
# volume with your experiment ConfigMap, volumeClaimTemplates -> null +
# emptyDir cache-huggingface, spec.template.spec.nodeName -> sashina
EOF
kubectl apply -f sts-bench.json
```

Suspend Flux first so reconcile does not fight the shadow objects:

```bash
flux suspend kustomization apps-llama-cpp -n flux-system   # resume after
```

### 3. One variable per run

The attribution matrix from 2026-09-11 (ctx 131072, KV q8_0, 2 RPC workers):

| config                                | decode t/s | delta   |
| ------------------------------------- | ---------- | ------- |
| baseline (no keys)                    | 10.4       | -       |
| `spec-type = draft-mtp` n-max 4 only  | 12.96      | +25%    |
| + `ubatch-size = 1024`                | 16.85      | +62%    |
| n-max 6                               | 14.1-14.8  | regress |
| 1 RPC worker (sashina-local)          | 19.33      | +86%    |

Per-model preset keys are scoped in `models-preset.ini` — they never leak to
other models (the embedding model has no MTP head).

### 4. Known traps

- **Deepseek wedge**: a `deepseek/deepseek-v4-flash` request that reaches the
  local floor starts an MXFP4 tensor stream that can wedge the router for 30+
  min and starve the liveness probe (restart loop). Benchmark only when that
  route fails over cleanly; see issue #2309 comment log.
- **Serialization is load-phase, not structural**: the router CAN serve another
  model while a slow load is download-bound (~36m cores); it starves only when
  the streaming phase saturates CPU.
- `--embeddings` is router-global → every child clamps `n_batch` to
  `n_ubatch` (512). Per-model `ubatch-size`/`batch-size` keys bypass it.
- `spec-draft-n-max` 4 is the measured optimum for this quant; 6 loses more on
  rejected-token verification than deeper drafts gain.
- The 888 MiB `mmproj` auto-loads with the LM and rides the RPC buffers.

## Landed configuration (PR #2312)

```ini
[qwen/qwen3.8-27b]
hf = unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_XL
spec-type = draft-mtp
spec-draft-n-max = 4
ubatch-size = 1024
batch-size = 4096
```

Verified post-deploy at 17.51 t/s on production (57.1 ms/token).

## Follow-up vectors (recorded, not implemented)

- Per-model RPC scoping: `LLAMA_ARG_RPC` is router-global, so the 1-worker
  placement (19.33 t/s) needs fork support or a second leader STS; the big
  models (glm-5.3-flash 98 GB, qwen3.8-flash 79 GB) still need both pools.
- Embeddings scoping (drop the router-global `--embeddings`).
- `mmproj` exclusion when vision input is not served (~0.9 GiB GTT back).
