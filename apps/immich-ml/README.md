# immich-ml

Immich machine-learning service (ghcr.io/immich-app/immich-machine-learning
v1.144.1-openvino): CLIP/face/object recognition for the immich server, on
:3003, reachable only from the immich pod (NetworkPolicy). Model caches are
ephemeral emptyDirs (cache-huggingface, cache-matplotlib, config-matplotlib).

## Layout

- `base/` — Deployment, Service, NetworkPolicy, VPA.
- `overlays/nishir/` — /dev/dri hostPath + privileged container, QSV node
  affinity, GPU acceleration enabled.
- `overlays/nishir-tailnet/` — `nishir-media` labels.
