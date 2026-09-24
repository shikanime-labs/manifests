---
name: llama-cpp-model-tuning
description: Use when lifting llama.cpp decode throughput on the RPC pair.
version: 0.1.0
author: Shikanime Deva, Hermes Agent
license: Apache-2.0
platforms: [linux, macos]
metadata:
  hermes:
    tags: [llama-cpp, throughput, tuning, rpc, inference, nishir]
    related_skills: [book-llama-cpp-inference]
---

# llama.cpp Local-Floor Throughput Tuning

A router model decodes well below its single-Halo reference (27B: 10.4 t/s vs
24-36 with MTP). Generic recipe: baseline, attribute gains one variable at a
time, land per-model preset keys in `models-preset.ini`.

## Prerequisites per model

From the model card / GGUF repo, before touching anything:

- Arch family: MTP head inside the GGUF (`mtp_num_hidden_layers` in
  config.json) vs standalone draft GGUF (`--spec-draft-hf` path).
- Attention layout: hybrid/linear attention (KV on some layers only) changes
  KV-cost math and quant headroom.
- Model size at the chosen quant vs one node's ~96 GiB GTT pool — decides
  whether the RPC split is capacity (needed) or pure latency (cost).
- Multimodal projector (mmproj, ~0.9 GiB) shipping alongside.

Architecture: `sts/llama-cpp` leader (router mode, ROCm GPU node since #2316,
privileged `/dev/kfd` + `/dev/dri`) + `sts/llama-cpp-rpc` worker, mutual
required anti-affinity; bonded 10 GbE (~65 us RTT) between them; leader dials
the worker via router-global `LLAMA_ARG_RPC`.

## Procedure

1. **Baseline on production, server-side numbers only.** Port-forward the
   leader, read `print_timing` from its log; client wall time is polluted by
   cold model load. Discard the first request per model; report only
   `eval time` (decode) and `prompt eval time` (prefill) lines.
2. **Shadow StatefulSet for experiments** — never patch prod in place. Clone
   the leader STS (name `llama-cpp-bench`, strip uid/resourceVersion, swap the
   preset ConfigMap, pin the node, VCT → emptyDir; models re-download ~6 min,
   RPC workers keep shards in `/cache/rpc` so re-loads take ~1 min). Suspend
   `apps-llama-cpp` Flux first; resume after.
3. **One variable per run**, in order — keep a value only on a positive delta:
   speculation (`spec-type = draft-mtp`, sweep `spec-draft-n-max` 2/4/6;
   acceptance is model-specific, 4 is not universal) → batch keys
   (`ubatch-size`/`batch-size` past the router-global embeddings clamp) →
   placement (single co-located RPC worker; only decisive for models fitting
   one node's pool).
4. **Land and verify.** Winning keys into the model's `[section]`, render, PR,
   deploy, re-measure on production — shadow numbers must reproduce on the
   real leader (27B: 17.51 t/s landed vs 16.85 shadow).

Worked example (27B, ctx 131072, KV q8_0, 2026-09-11): baseline 10.4 →
draft-mtp n4 12.96 → +ubatch 1024 16.85 → n6 regressed 14.1-14.8 → 1 local
worker 19.33 t/s.

## Gotchas

- Sharded unsloth GGUF repos are broken upstream: shard `*-00001-of-*.gguf` is
  metadata-only (`n_tensors=0`); loader streams ~120 GB then dies
  `tensor read out of bounds`. Fix is the preset source
  (`lmstudio-community` single-file builds, PR #2307), not re-download.
- Cached presets shadow the ini: `load_models()` merges presets cached in the
  HF PVC by section name and a cached `hf=` wins — after editing a section,
  delete `models--<org>--<repo>` from the PVC or the change never takes.
- `LLAMA_ARG_RPC` is router-global: a dead host in the list kills every child
  at spawn (`ggml-rpc.cpp` abort in `common_params_parse`, looks like a preset
  bug; it is connectivity). A suspended `apps-llama-cpp` KS freezes the old
  value — verify live env against main before blaming presets.
- `--embeddings` is router-global → every child clamps `n_batch` to
  `n_ubatch` (512); per-model `ubatch-size`/`batch-size` bypass it.
- MXFP4 streams cleanly; the deepseek 30-min wedge was the broken-shard
  stream, not MXFP4 behavior (issue #2309).
- `spec-draft-n-max` is per-model — re-sweep, never copy blind. The mmproj
  (~0.9 GiB) auto-loads and rides the RPC buffers.
- Preset keys ARE CLI flags (kebab-case, no `--`): a key that is not a flag
  silently does nothing. Context is `c`, NOT batch-size — `-b`/`batch-size`
  is the logical batch (compute buffer sizing, upstream #9784); batch-tuning
  keys are `ubatch-size`/`batch-size` and ctx keys are `c`/`ctx-size`.
- Qwen3.8 context: 262144 native; 1M is YaRN-only — do not request native
  1M ctx.
- `llama-server` runs as PID 1 with every flag via `LLAMA_ARG_*` env vars;
  the HF cache lives on a dedicated `cache-huggingface` emptyDir at
  `/root/.cache/huggingface` (default HOME path — an env override breaks
  the lazy re-download).
- Lazy model loading: presets point at Unsloth `repo:quant` so first request
  downloads on demand; a failed/partial download surfaces as a load error
  on the first request, not at startup.

## Verification

Re-measured production `eval time` on the leader matches or beats the shadow
number; the embedding model (no MTP head) unaffected; gateway route serving.
