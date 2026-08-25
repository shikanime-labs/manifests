# Manifests

Kubernetes manifests and GitOps configurations for Shikanime infrastructure,
managed via FluxCD and structured around Kustomize.

**Language:** YAML

## Top-Level Layout

The repository separates **what runs an app** from **what the platform
provides** from **how operators are installed**. Conventions:

- The root-level directories are the **domain split**. Within each tree, every
  resource manifest is named `<short-kube-resource-name>.yaml` (e.g. `sts.yaml`,
  `svc.yaml`, `vpa.yaml`, `hr.yaml`, `netpol.yaml`, `pvc.yaml`,
  `recurringjob.yaml`).
- `apps/` — Application workloads. One directory per app; each holds the
  workload plus its Service/Ingress and per-cluster overlays.
- `infrastructure/` — Per-operator platform deployments. Mostly Flux
  `HelmRelease` (`*hr.yaml`) plus a `helmrepo.yaml` per source; some carry a
  base `ns.yaml`, `vpa.yaml`, and a `components/monitoring/` block.
- `configs/` — Global, operator-dependent configuration that is NOT tied to a
  single app: storage classes, recurring jobs, issuers, trust bundles,
  gatekeeper mutations, cluster-api machine templates. Consumed by
  `infrastructure/` and `clusters/`.
- `modules/` — Reusable Kustomize/Terraform modules shared across trees
  (e.g. `modules/longhorn/`).
- `clusters/` — Cluster entrypoints that compose cluster base + components +
  selected app overlays.
- `bootstraps/` — Out-of-band controller/operator installation (Flux
  `HelmChart` resources). The Kustomize overlays assume these already exist.
- `skaffold.yaml` — Renderable profiles pointing at cluster overlay
  entrypoints.

### `apps/` (application workloads)

- `apps/<app>/base/` — Common resources (`Deployment`/`StatefulSet`, `Service`,
  `Ingress`, `vpa.yaml`, `pvc.yaml` as needed)
- `apps/<app>/components/` — Optional Kustomize components (e.g. `tls/`,
  `ftp/`, `v4l/`)
- `apps/<app>/overlays/<cluster>/` — Cluster-specific patches/config
- `apps/<app>/overlays/<cluster>-tailnet/` — Tailnet flavor overlays

Nested examples: `hermes-agent/{dashboard,gateway}`,
`servarr/{lidarr,radarr,sonarr,whisparr}`, `mautrix/{discord,whatsapp,...}`.

### `infrastructure/` (operator/platform deployments)

- `infrastructure/<operator>/base/` — `helmrepo.yaml`, `*hr.yaml`
  (`HelmRelease`), `ns.yaml`, `vpa.yaml`
- `infrastructure/<operator>/components/monitoring/` — `vmservicescrape.yaml`
  and friends
- `infrastructure/<operator>/overlays/<cluster>/` — per-cluster HR patches
  (`patch-hr.yaml`)

### `configs/` (global operator-dependent config)

- `configs/<area>/base/` — shared resources (StorageClass, recurring jobs,
  issuers, mutations, machine templates)
- `configs/<area>/overlays/<cluster>/` — cluster-specific patches

Examples: `cert-manager`, `cluster-api`, `gatekeeper`, `longhorn`,
`node-feature-discovery`, `tailscale`.

### `clusters/` (entrypoints)

- `clusters/<cluster>/base/` — Namespaces, shared PVCs, default policies
- `clusters/<cluster>/components/` — Cluster-wide components (`tls/`,
  `tailscale/`, `longhorn/`, `monitoring/`, `gatekeeper/`, ...)
- `clusters/<cluster>/overlays/<overlay>/` — Build entrypoints composing
  base + components + app overlays

## Clusters

- `nishir` — overlay: `tailnet`; components: autoscaler, cert-manager,
  cluster-api, descheduler, envoy-ai-gateway, gatekeeper, longhorn,
  monitoring, kubevirt, node-feature-discovery, tailscale, trust-manager
- `telsha` — overlay: `tailnet`; components: autoscaler, cert-manager,
  cluster-api, gatekeeper, monitoring, tailscale, trust-manager

## Cluster Services

- **TLS/trust:** cert-manager issuers/certs + trust-manager `Bundle`
- **Tailnet ingress:** Tailscale Operator credentials
- **Storage:** Longhorn settings, storage class, recurring jobs
- **Observability:** VictoriaMetrics stack + Grafana (exposed over Tailscale)
- **VPA:** Every app and operator base includes `vpa.yaml` — the VPA
  controller must be present

## App Pattern

- Workload: `Deployment` or `StatefulSet` in `apps/<app>/base/`
- Network: `Service` + `Ingress` in base; tailnet overlays set
  `ingressClassName: tailscale` + Tailscale annotations
- Storage: `PVC` in `apps/<app>/overlays/<cluster>/` bound to a Longhorn `PV`
- Images: `newTag: <version>@sha256:...` pinned in `kustomization.yaml`, plus
  an `automata.shikanime.studio/images` tag-regex annotation for automated
  bumps

## Secrets

The repo is kept open-source: SOPS encrypts **only selected fields**, not whole
files.

- SOPS uses per-app `encrypted_regex` rules (defined in `flake.nix`); only
  matched keys are ciphertext, the rest of the file stays plaintext.
- Encrypted files use the `*.enc.*` naming pattern (e.g. `.enc.env`,
  `config.enc.yaml`, `LDAP-Auth.enc.xml`), including leading-dot files such as
  `apps/lldap/overlays/nishir/lldap/.enc.env`.
- Flux decrypts `.enc.*` transparently via its SOPS integration at reconcile
  time; no manual filename stripping is performed or committed.
- Secret files live in a **subfolder named after the secret** (e.g.
  `discord-webhook/.enc.env`, `receiver-token/.enc.env`).
- `clusters/<cluster>/overlays/<overlay>/` wires these into Flux
  `secretGenerator` entries (`discord-webhook`, `receiver-token` in
  `flux-system`).
- Never commit decrypted outputs — change the encrypted source instead.

## Commit Style

- Plain-text capitalized title, no conventional-commit prefix
- Body with labels: `Design:`, `Related:`, `Closes #`
- Keep Markdown lines wrapped at 80 columns and run `nix fmt` (treefmt) before
  shipping. The `gitlint` commit-msg hook enforces the title style locally.

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

