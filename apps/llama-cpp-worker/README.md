# llama-cpp-worker

RPC peer for the llama.cpp router (`apps/llama-cpp/`): a single-replica
StatefulSet `llama-cpp-worker` running `ggml-rpc-server --host 0.0.0.0
--port 50052 --cache` in `shikanime`. It hosts the layer shards the
leader offloads via its preset `rpc =` keys (MoE models only — dense
models load leader-local).

- Image: the same unified `ghcr.io/shikanime-labs/machines/llama-cpp`
  digest as the leader (RPC has no protocol handshake — leader/worker
  builds must match).
- Storage: 256Gi `longhorn-scratch` VCT `cache` mounted at `/cache`
  (`LLAMA_CACHE=/cache`). RPC tensor shards persist across model
  reloads, so a reload takes ~1 min instead of a full re-stream;
  poisoned shard state dies on worker restart alone.
- Scheduling: the same GPU node affinity as the leader
  (`feature.node.kubernetes.io/pci-0380_1002.present`) plus required
  `podAntiAffinity` against the leader label pair, so the two pods land
  on separate MS-S1 nodes.
- Network: macvlan NAD `llama-cpp-worker` (overlay `nishir/nad.yaml`,
  bridge on `br1`, static IPAM `10.66.1.1/24`) attached through the pod
  annotation `k8s.v1.cni.cncf.io/networks`. The leader preset dials the
  static address (`rpc = 10.66.1.1:50052`); the leader's own lane NAD
  `llama-cpp` uses whereabouts dynamic IPAM (10.66.1.100-200). If the
  worker pod's `network-status` annotation ever disagrees with the
  preset, fix the address, not the model.
- `netpol.yaml`: ingress only from the leader pods, on port `rpc`.
- `vpa.yaml`: InPlace VPA on the StatefulSet.
