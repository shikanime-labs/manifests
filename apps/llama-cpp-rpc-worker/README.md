# llama-cpp-rpc-worker

RPC peer for the flash head (`apps/llama-cpp-rpc-head/`): a
single-replica StatefulSet `llama-cpp-rpc-worker` running
`ggml-rpc-server --host 0.0.0.0 --port 50052 --cache` in `shikanime`.
It hosts the layer shards the head offloads via its preset `rpc =` key.

## Layout

- `base/` — StatefulSet, VPA.
- `overlays/nishir/` — macvlan NAD `llama-cpp-rpc-worker` (bridge on
  `br1`, static IPAM `10.66.1.1/24`, attached via the pod annotation
  `k8s.v1.cni.cncf.io/networks`), netpol admitting only the head pods
  on port `rpc`, node PV for the 256Gi `longhorn-scratch` PVC `cache`
  (`LLAMA_CACHE=/cache`; RPC tensor shards persist across reloads, so a
  reload takes ~1 min instead of a full re-stream, and poisoned shard
  state dies on worker restart alone).
- Image: the same unified `ghcr.io/shikanime-labs/machines/llama-cpp`
  digest as the head (RPC has no protocol handshake — builds must
  match).
- Scheduling: the same GPU node affinity
  (`feature.node.kubernetes.io/pci-0380_1002.present`) plus required
  `podAntiAffinity` against the head, so the two pods land on separate
  MS-S1 nodes.
- If the worker pod's `network-status` annotation ever disagrees with
  the preset address, fix the address, not the model.
