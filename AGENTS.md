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

## Repository Layout

- `apps/` — application manifests
  - nested examples: `hermes-agent/{dashboard,gateway}`,
    `servarr/{lidarr,radarr,sonarr,whisparr}`, `mautrix/{discord,whatsapp,...}`
- `clusters/` — cluster entrypoints
- `bootstraps/` — controller/operator installation
- `configs/` — reusable configuration blocks (`cert-manager`, `cluster-api`,
  `gatekeeper`, `longhorn`, `tailscale`, ...)
- `infrastructure/` — infrastructure providers/manifests
  - examples: `cert-manager`, `cluster-api`, `longhorn`, `tailscale`,
    `monitoring`, `trust-manager`
- `modules/` — reusable Kustomize modules
- `skaffold.yaml` — render profiles
- `flake.lock` / AGENTS.md / `README.md` at repo root

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

## Stack Workflow

- Install the official GitHub extension once:
  `gh extension install github/gh-stack` (requires GitHub CLI ≥ 2.0; `gh stack`
  is in public preview and may change).
- Keep one logical change per PR; split large work into a stack of PRs.
- Create a stack: `gh stack init`, then `gh stack add` for each new branch, and
  commit on the active branch. `gh stack view` lists the stack.
- Submit/update: `gh stack submit` (add `--open` to open PRs, `--auto` to skip
  prompts). Resubmit after each change to refresh titles, bodies, and branches.
- Pull down an existing stack: `gh stack checkout <PR_NUMBER>` (also accepts a
  stack number, PR URL, or branch name).
- Rebase onto updated trunk: `gh stack rebase` (cascading), then
  `gh stack submit`.
- Land a stack: `gh stack merge` (interactive) or
  `gh stack merge <PR_NUMBER> --yes --squash` to merge up to a PR.
- Never `gh pr merge` on a stacked PR — only `gh stack merge` lands stacks.
- Never force-push stack branches; `gh stack` owns the branch pointers.
