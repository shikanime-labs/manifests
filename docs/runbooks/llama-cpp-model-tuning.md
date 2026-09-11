# llama.cpp local-floor throughput optimization

<!-- owner: shikanime studio | zone: internal | purpose: generic methodology to measure and lift decode t/s for any router model on the MS-S1 RPC pair -->

## Problem

A router model decodes well below its single-Halo reference (e.g. 27B: 10.4
t/s vs 24-36 t/s with MTP, issue #2309). This runbook is the generic recipe:
measure a baseline, attribute gains one variable at a time, land per-model
preset keys. It applies to any `[section]` in `models-preset.ini`; the 27B
numbers are kept as the worked example.

## Prerequisites per model

Before tuning, establish from the model card / GGUF repo:

- Arch family: does it ship an MTP head inside the GGUF
  (`mtp_num_hidden_layers` in config.json), or does the repo publish a
  standalone draft GGUF (`--spec-draft-hf` path)?
- Attention layout: hybrid/linear attention (KV only on some layers) changes
  KV-cost math and quant headroom.
- Model size at the chosen quant vs one node's ~96 GiB GTT pool — decides
  whether the 2-worker RPC split is capacity (needed) or pure latency (cost).
- Whether a multimodal projector ships alongside (mmproj, ~0.9 GiB here).

## Architecture under test

- `sts/llama-cpp` (leader, CPU-only `llama-server` in router mode, port 8080)
- `sts/llama-cpp-rpc` (2 × `ggml-rpc-server`, one per MS-S1, `/dev/kfd` + `/dev/dri`)
- Leader dials both workers via `LLAMA_ARG_RPC` (router-global env — see
  Traps).
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
  -d '{"model":"<router id>","messages":[...],"max_tokens":256}'
kubectl logs -n shikanime llama-cpp-0 | grep 'print_timing.*eval time' | tail
```

Discard the first request per model (cold load; a transient HF fetch of an
auxiliary GGUF can 500 once and the router retries). Report only the
`eval time = X ms / N tokens` (decode) and `prompt eval time` (prefill) lines.

### 2. Shadow StatefulSet for experiments — never patch prod in place

Clone the leader STS, swap the preset ConfigMap, pin the node, drop the PVC to
emptyDir (models re-download in ~6 min; RPC workers keep tensor shards in
`/cache/rpc` so re-loads take ~1 min):

```bash
kubectl get sts -n shikanime llama-cpp -o json | python3 - <<'EOF'
# name -> llama-cpp-bench, strip uid/resourceVersion, replace models-preset
# volume with your experiment ConfigMap, volumeClaimTemplates -> null +
# emptyDir cache-huggingface, spec.template.spec.nodeName -> <node>
EOF
kubectl apply -f sts-bench.json
```

Suspend Flux first so reconcile does not fight the shadow objects:

```bash
flux suspend kustomization apps-llama-cpp -n flux-system   # resume after
```

### 3. One variable per run

Tune in this order; keep the last value only if the delta is positive:

1. Speculation (only if the arch ships a head): `spec-type = draft-mtp`,
   sweep `spec-draft-n-max` over 2/4/6 — acceptance quality is model-specific
   and 4 is not universal.
2. Batch keys: `ubatch-size` / `batch-size` past the router-global embeddings
   clamp (see Traps). Verify prefill t/s before/after.
3. Placement: repeat the best config with a single RPC worker
   (`LLAMA_ARG_RPC` pointing at the co-located worker only) — only decisive
   for models that fit one node's pool.

Worked example — 27B (ctx 131072, KV q8_0, 2 RPC workers, 2026-09-11):

| config                               | decode t/s | delta   |
| ------------------------------------ | ---------- | ------- |
| baseline (no keys)                   | 10.4       | -       |
| `spec-type = draft-mtp` n-max 4 only | 12.96      | +25%    |
| + `ubatch-size = 1024`               | 16.85      | +62%    |
| n-max 6                              | 14.1-14.8  | regress |
| 1 RPC worker (sashina-local)         | 19.33      | +86%    |

Per-model preset keys are scoped in `models-preset.ini` — they never leak to
other models (verify: the embedding model has no MTP head and must keep
serving).

### 4. Land and verify

Copy the winning keys into the model's `[section]`, render, PR, deploy, then
re-measure on production — the shadow numbers must reproduce on the real
leader (27B: 17.51 t/s landed vs 16.85 shadow).

## Traps

- **Deepseek wedge**: a `deepseek/deepseek-v4-flash` request that reaches the
  local floor starts an MXFP4 tensor stream that can wedge the router for 30+
  min and starve the liveness probe (restart loop). Benchmark only when that
  route fails over cleanly; see issue #2309 comment log.
- **Serialization is load-phase, not structural**: the router CAN serve another
  model while a slow load is download-bound (~36m cores); it starves only when
  the streaming phase saturates CPU.
- `--embeddings` is router-global → every child clamps `n_batch` to
  `n_ubatch` (512). Per-model `ubatch-size`/`batch-size` keys bypass it.
- `LLAMA_ARG_RPC` is router-global: a single-worker placement helps
  node-fitting models but starves the big ones (glm-5.3-flash 98 GB,
  qwen3.8-flash 79 GB need both pools). Do not land placement wins for one
  model as router-global changes.
- `spec-draft-n-max` is per-model: the 27B optimum (4) regressed at 6;
  re-sweep per model, never copy blind.
- The mmproj (~0.9 GiB) auto-loads with the LM and rides the RPC buffers.

## Reference results per model

| model                | quant      | landed decode | notes                       |
| -------------------- | ---------- | ------------- | --------------------------- |
| qwen/qwen3.8-27b     | UD-Q4_K_XL | 17.51 t/s     | PR #2312, from 10.4 baseline |

Append a row per tuned model; keep raw runs in the linked issue.

## Follow-up vectors (recorded, not implemented)

- Per-model RPC scoping in the fork (placement win without starving big
  models).
- Embeddings scoping (drop the router-global `--embeddings`).
- `mmproj` exclusion when vision input is not served (~0.9 GiB GTT back).
