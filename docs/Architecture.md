<!-- owner: shikanime | zone: internal | purpose: manifests architecture and cluster layout -->

# Architecture

`manifests` holds Shikanime's Kubernetes manifests, managed via FluxCD and
structured around Kustomize. The repo splits **what runs an app** from
**what the platform provides** from **how operators are installed**.

## Domain split

- `apps/` — application workloads; one dir per app with
  `base/`, `components/`, `overlays/<cluster>/`, `overlays/<cluster>-tailnet/`
- `infrastructure/` — per-operator platform deploys (`*hr.yaml` HelmRelease,
  `helmrepo.yaml`, `ns.yaml`, `vpa.yaml`, `components/monitoring/`)
- `configs/` — global operator-dependent config (storage classes, issuers,
  trust bundles, gatekeeper mutations, machine templates)
- `modules/` — reusable Kustomize/Terraform modules
- `clusters/` — entrypoints composing cluster `base` + `components` + app
  overlays
- `bootstraps/` — out-of-band controller/operator install (Flux `HelmChart`)

## Clusters

- `nishir` — overlay `tailnet`; components: autoscaler, cert-manager,
  cluster-api, descheduler, envoy-ai-gateway, gatekeeper, longhorn,
  monitoring, kubevirt, node-feature-discovery, tailscale, trust-manager
- `telsha` — overlay `tailnet`; components: autoscaler, cert-manager,
  cluster-api, gatekeeper, monitoring, tailscale, trust-manager

## Secrets

SOPS encrypts **selected fields only** via per-app `encrypted_regex` rules in
`flake.nix`. Encrypted files use `*.enc.*` and live in a subfolder named
after the secret; Flux decrypts them transparently at reconcile time.

## Inference

`apps/llama-cpp/<name>/` are Envoy AI Gateway `AIGatewayRoute` workloads
exposed over Tailscale BYOD L4; control plane under `infrastructure/envoy/`.
