<!-- owner: shikanime | zone: internal | purpose: directory layout and command surface -->

# Reference

## Directory map

| Path             | Contents                                         |
| ---------------- | ------------------------------------------------ |
| `apps/`          | app bases, components, per-cluster overlays      |
| `infrastructure/`| operator `HelmRelease`s, helm repos, monitoring  |
| `configs/`       | storage, issuers, trust, gatekeeper, NFD, tailscale |
| `modules/`       | reusable Kustomize/Terraform modules             |
| `clusters/`      | `base/`, `components/`, `overlays/<overlay>/`    |
| `bootstraps/`    | Flux `HelmChart` controller installs             |
| `skaffold.yaml`  | render profiles per cluster overlay              |

## Cluster components

- `nishir`: autoscaler, cert-manager, cluster-api, descheduler,
  envoy-ai-gateway, gatekeeper, longhorn, monitoring, kubevirt,
  node-feature-discovery, tailscale, trust-manager
- `telsha`: autoscaler, cert-manager, cluster-api, gatekeeper, monitoring,
  tailscale, trust-manager

## Secret conventions

- `*.enc.*` naming (`.enc.env`, `config.enc.yaml`, `LDAP-Auth.enc.xml`)
- file lives in a subfolder named after the secret (`discord-webhook/.enc.env`)
- Flux `secretGenerator` in `clusters/<cluster>/overlays/<overlay>/`

## Commands

| Command                       | Purpose                  |
| ----------------------------- | ------------------------ |
| `nix fmt`                     | treefmt the repo         |
| `skaffold render -p <c>-tailnet` | preview composed overlay |
| `gitlint`                     | validate commit message  |
