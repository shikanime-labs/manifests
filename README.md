<!-- markdownlint-disable first-line-heading MD041 -->

![header.png](https://raw.githubusercontent.com/shikanime/shikanime/main/assets/github-header.png)

<!-- markdownlint-enable first-line-heading -->

# Manifests

Hey 🌸 I'm Shikanime Deva, this repository contains the Kubernetes manifests for
my clusters.

## What’s In Here

This repo is organized around Kustomize:

- `apps/` contains application manifests (bases, optional components, and
  per-cluster overlays)
- `clusters/` contains cluster entrypoints that compose shared cluster bits +
  app overlays
- `bootstraps/` contains cluster bootstrap inputs (controllers/operators
  installation lives here)
- `skaffold.yaml` provides renderable profiles that point at the cluster overlay
  entrypoints

### Repository Layout

#### Apps

Each app is typically structured like:

- `apps/<app>/base/`: app resources that are common everywhere
- `apps/<app>/components/`: optional Kustomize components (e.g. `tls/`, `ftp/`,
  `v4l/`)
- `apps/<app>/overlays/<cluster>/`: cluster-specific patches/config
- `apps/<app>/overlays/<cluster>-tailnet/`: cluster-specific overlays for the
  “tailnet” flavor (when applicable)

#### Clusters

Each cluster typically looks like:

- `clusters/<cluster>/base/`: namespaces, shared PVCs, default policies, etc.
- `clusters/<cluster>/components/`: cluster-wide components (e.g. `tls/`,
  `tailscale/`, `longhorn/`)
- `clusters/<cluster>/overlays/<overlay>/`: build entrypoints that compose
  cluster base + components + selected app overlays

For example, `clusters/nishir/overlays/tailnet/kustomization.yaml` pulls in
cluster components and a list of `apps/*/overlays/nishir-tailnet`, plus the
cluster `base`.

## Architecture

This repository is intentionally split into two concerns:

- Compose and configure cluster services and apps with Kustomize (`clusters/` +
  `apps/`)
- Bootstrap the controllers/operators those manifests depend on (`bootstraps/`)

### Bootstrap

The Kustomize overlays assume the underlying controllers/operators already
exist. Those are installed out-of-band using the manifests in `bootstraps/`.

- `bootstraps/telsha/` contains `HelmChart` resources
  ([helmchart.yaml](bootstraps/telsha/helmchart.yaml))

### Clusters

This repo currently defines two cluster trees:

- `clusters/nishir/` (overlay: `tailnet`, components: kubevirt, longhorn,
  tailscale, tls, victoriametrics)
- `clusters/telsha/` (overlay: `tailnet`, component: tailscale)

### Cluster Services (Add-ons)

The “cluster services” in this repo are mostly configuration and glue for
controllers installed during bootstrap.

- TLS / trust distribution:
  - cert-manager resources (issuers/certs) under
    `clusters/<cluster>/components/tls/`
  - trust-manager `Bundle` to publish CA material to workloads as a ConfigMap
- Tailnet ingress:
  - Tailscale Operator credentials under
    `clusters/<cluster>/components/tailscale/`
- Storage:
  - Longhorn settings, storage class, and recurring jobs under
    `clusters/<cluster>/components/longhorn/`
- Observability:
  - VictoriaMetrics stack under `clusters/<cluster>/components/victoriametrics/`
  - Grafana is part of the VictoriaMetrics stack and is exposed over Tailscale
    ingress in the `nishir` overlay
- Vertical Pod Autoscaler:
  - many apps include `vpa.yaml` and expect a VPA controller to be present
- Virtualization (KubeVirt):
  - installed via the version-pinned operator manifest under
    `infrastructure/kubevirt/base/operator.yaml` plus a `KubeVirt` CR
    (`kubevirt-cr.yaml`), reconciled by the `infrastructure-kubevirt` Flux
    `Kustomization`
  - KubeVirt has **no official Helm chart**; the upstream install method is the
    operator + CR manifest pair, so this component diverges from the
    `HelmRelease` pattern used elsewhere
  - the operator manifest already sets the `kubevirt-system` namespace to the
 `privileged` Pod Security Standard
  - **host prerequisites** (per node that should run VMs):
    - hardware virtualization exposed as `/dev/kvm` — requires Intel VT-x
      (`vmx`) or AMD-V (`svm`) in `/proc/cpuinfo`; check with `ls -l /dev/kvm`
    - if nodes are themselves virtual machines, **nested virtualization** must
      be enabled on the hypervisor, otherwise `/dev/kvm` is absent
    - absent `/dev/kvm` falls back to slow software emulation unless the
      `KubeVirt` CR sets
      `spec.configuration.developerConfiguration.useEmulation`
    - `virt-handler` runs as a DaemonSet on every node; VM scheduling keys off
      the `nodes.kubevirt.io/resource/kvm` label that KubeVirt publishes when
      `/dev/kvm` is present (node-feature-discovery is already deployed)
    - VM disks need a `StorageClass` — Longhorn is present; pair with CDI for
      `DataVolume` imports (not yet installed in this repo)
    - mixed `amd64`/`arm64` nodes are supported, but each node still needs
      `/dev/kvm` for its architecture

### How Apps Plug In

Most apps follow the same pattern:

- Workload: `Deployment` or `StatefulSet` in `apps/<app>/base/`
- Network: `Service` + `Ingress` in `apps/<app>/base/`
  - generic ingress shape lives in base
  - tailnet overlays own the rendered `ingress.yaml` and set
    `ingressClassName: tailscale` plus Tailscale annotations (example:
    [ingress.yaml](apps/jellyfin/overlays/nishir-tailnet/ingress.yaml))
  - cluster-local internal hosts are prefixed where needed, such as `grafana`
- Storage: a `PVC` in `apps/<app>/overlays/<cluster>/` (or `*-tailnet/`) bound
  to a Longhorn `PV`
- Secrets/config: stored as `*.enc.*` and fed into `secretGenerator` (see
  [Secrets](#secrets))

### Secrets

Sensitive values are stored encrypted in-repo and materialized at render/apply
time.

- Encrypted files use the `*.enc.*` naming pattern (examples: `.enc.env`,
  `config.enc.yaml`).
- Decrypted outputs are derived by stripping `.enc.` from the filename (example:
  `.enc.env` → `.env`).
- Never commit decrypted outputs. Change the encrypted source instead.
