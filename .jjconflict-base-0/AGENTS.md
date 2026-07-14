# Manifests

Kubernetes manifests and GitOps configurations for Shikanime infrastructure,
managed via FluxCD and structured around Kustomize.

**Language:** YAML

## Structure

- `apps/` — Application manifests
  - `apps/<app>/base/` — Common resources (Deployment/StatefulSet, Service,
    Ingress)
  - `apps/<app>/components/` — Optional Kustomize components (e.g. `tls/`,
    `ftp/`, `v4l/`)
  - `apps/<app>/overlays/<cluster>/` — Cluster-specific patches
  - `apps/<app>/overlays/<cluster>-tailnet/` — Tailnet flavor overlays
- `clusters/` — Cluster entrypoints
  - `clusters/<cluster>/base/` — Namespaces, shared PVCs, default policies
  - `clusters/<cluster>/components/` — Cluster-wide components (`tls/`,
    `tailscale/`, `longhorn/`, `victoriametrics/`)
  - `clusters/<cluster>/overlays/<overlay>/` — Build entrypoints composing
    base + components + app overlays
- `bootstraps/` — Controller/operator installation (HelmChart resources)
  - `bootstraps/telsha/`
- `skaffold.yaml` — Renderable profiles pointing at cluster overlay entrypoints

## Clusters

- `nishir` — overlay: `tailnet`; components: longhorn, tailscale, tls,
  victoriametrics
- `telsha` — overlay: `tailnet`; component: tailscale

## Cluster Services

- **TLS/trust:** cert-manager issuers/certs + trust-manager `Bundle`
- **Tailnet ingress:** Tailscale Operator credentials
- **Storage:** Longhorn settings, storage class, recurring jobs
- **Observability:** VictoriaMetrics stack + Grafana (exposed over Tailscale)
- **VPA:** Many apps include `vpa.yaml` — ensure VPA controller is present

## App Pattern

- Workload: `Deployment` or `StatefulSet` in `apps/<app>/base/`
- Network: `Service` + `Ingress` in base; tailnet overlays set
  `ingressClassName: tailscale` + Tailscale annotations
- Storage: `PVC` in `apps/<app>/overlays/<cluster>/` bound to Longhorn `PV`
- Secrets/config: `*.enc.*` files fed into `secretGenerator`

## Secrets

- Encrypted files use `*.enc.*` naming (e.g. `.enc.env`, `config.enc.yaml`)
- Decrypted outputs derived by stripping `.enc.` from filename
- Never commit decrypted outputs — change the encrypted source instead

## Commit Style

- Plain-text capitalized title, no conventional-commit prefix
- Body with labels: `Design:`, `Related:`, `Closes #`
- Keep Markdown lines wrapped at 80 columns and run `nix fmt` before shipping

## Stack

- 1 commit == 1 PR via ghstack
- Amend + `ghstack` to resubmit
- `ghstack land` on head PR to land the entire stack
- Never `gh pr merge` (creates poisoned commits)
- Never force-push ghstack branches
- ghstack only works on HEAD commit chains, not detached HEADs

## Protect `main`

- Require 1 approving review
- Require linear history (no merge commits)
- Require signed commits
- Squash+rebase merge only

_Managed via FluxCD. Lint all manifests with `kustomize build` before
committing. Always use worktrees when making changes._
