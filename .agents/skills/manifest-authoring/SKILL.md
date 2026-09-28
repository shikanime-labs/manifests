---
name: manifest-authoring
description:
  "Use when authoring or editing Kubernetes manifests in a shikanime repo:
  one-kind-per-file naming, sorted resources lists, base/overlays shape, labels,
  pod-port probes, YAGNI on new abstractions."
version: 0.1.0
author: Hermes Agent
license: Apache-2.0
metadata:
  hermes:
    tags:
      - kubernetes
      - manifests
      - kustomize
      - flux
      - yaml
      - shikanime-labs
      - manifests-repo
    related_skills:
      - overlay-authoring
      - sops-secrets-authoring
      - vpa-memory-floor-audit
      - workload-migration
platforms:
  - linux
  - macos
  - windows
---

# shikanime manifest authoring

Author and edit Kubernetes manifests in `shikanime-labs/manifests` following the
repo's structure and conventions. The repo is Kustomize-based, split into
`apps/`, `clusters/`, `configs/`, `infrastructure/`, and `bootstraps/` — with one
Kubernetes kind per file, sorted `resources:` lists, and the repo's own labeling,
probe, storage, and netpol discipline, grounded in the repo's README and the actual
base layouts observed across the fleet (metatube, syncthing, catbox, blackbox,
qbittorrent, the inference/llama-cpp trees, cluster-api, cert-manager,
grafana-operator, and the bootstraps tree).

## When to use

- Adding or editing a workload, Service, route, PVC, VPA, netpol, HelmRelease,
  namespace, or kustomization in `shikanime-labs/manifests`.
- Deciding where a new resource lives: `apps/`, `clusters/`, `infrastructure/`,
  `configs/`, or `bootstraps/`.
- Choosing between a base file, an overlay patch, a component, or a new tree.
- Verifying a tree builds before shipping.

Don't use for: editing the Nix that *generates* manifests — that is
`s sks-nix-authoring`. Don't use for sops-encrypted secret files — that is
`sops-authoring`. Don't use for commit style — that is `sks-commit`.

## Repo map (from `shikanime-labs/manifests/README.md` and the file tree)

The repo separates concerns into five top-level trees plus a sixth bootstrap tree.
Place each resource in the bucket that owns it.

|  Tree                          | Owns                                                                   |
|  ---------------------------- | ---------------------------------------------------------------------- |
|  `apps/<app>/`                 | Application workloads. One dir per app.                               |
|  `apps/<app>/base/`            | Resources common to every cluster the app runs on.                    |
|  `apps/<app>/components/`      | Optional Kustomize components (e.g. `tls/`, `ftp/`, `v4l/`, …).      |
|  `apps/<app>/overlays/<cluster>/`   | Cluster-specific patches/config for `<cluster>`.                  |
|  `apps/<app>/overlays/<cluster>-tailnet/` | Tailnet flavor overlay (hostnames) for `<cluster>`.         |
|  `clusters/<cluster>/`         | Cluster entrypoint and shared cluster bits.                           |
|  `clusters/<cluster>/base/`    | Namespaces, shared PVCs, default policies for that cluster.           |
|  `clusters/<cluster>/components/` | Cluster-wide components (tls, tailscale, longhorn, monitoring, …). |
|  `clusters/<cluster>/overlays/<overlay>/` | Build entrypoint composing base + components + app overlays. |
|  `infrastructure/<operator>/`  | Per-operator platform deployments, mostly Flux `HelmRelease` +        |
|                               | `helmrepo.yaml`; some carry base `ns.yaml`, `vpa.yaml`, and a          |
|                               | `components/monitoring/` block.                                       |
|  `configs/<area>/`             | Global, operator-dependent config NOT tied to a single app (storage   |
|                               | classes, issuers, mutations, machine templates).                     |
|  `bootstraps/<cluster>/`       | Out-of-band controller/operator installation (Flux `HelmChart`        |
|                               | resources). The Kustomize overlays assume these already exist.        |

Reading the file tree is enough to answer "where does this go?" in most cases:

- **App-owned resource** → `apps/<app>/`. If it differs per cluster, put the
  common part in `base/` and the per-cluster patch in `overlays/<cluster>/`.
- **Cluster-shared resource** (namespace, shared PVC, default policy) →
  `clusters/<cluster>/base/`.
- **Cluster-wide component** consumed by many apps (monitoring scrape, tailscale,
  longhorn settings) → `clusters/<cluster>/components/<name>/`.
- **Operator/platform deployment** (cert-manager, longhorn, gatekeeper, envoy) →
  `infrastructure/<operator>/`.
- **Global config not app-tied** (storage class, recurring jobs, issuers, machine
  templates) → `configs/<area>/`.
- **Bootstrap controller install** (the operator that the overlays assume exists) →
  `bootstraps/<cluster>/`.

## Per-app shape (the common case)

Most apps follow the same pattern, observed across the repo's existing apps:

```text
apps/<app>/
  base/
    <kind>.yaml          # one kind per file, short resource name
    kustomization.yaml   # resources: sorted list
  components/
    tls/                 # optional: opt-in TLS component
    …                   # other optional components
  overlays/
    <cluster>/           # cluster-specific patches
    <cluster>-tailnet/   # tailnet flavor (hostnames), when applicable
```

A base dir typically contains: workload (`sts.yaml` or `deploy.yaml`), `svc.yaml`,
an ingress route (`httproute.yaml` or `httproutes.yaml`), `vpa.yaml`, optionally
`netpol.yaml` and `pvc.yaml`, and a `kustomization.yaml` — plus optional
operator-specific kinds for inference apps (`aiservicebackend.yaml`,
`backend.yaml`, `backendsecuritypolicy.yaml`, `vmprobe.yaml`, `vmrule.yaml`,
`vmservicescrape.yaml`, `llama-cpp-models-preset`).

Observed per-app base layouts (exact, from the repo):

- Plain app (metatube, syncthing, authelia, jellyfin, copyparty, forgejo): one of
  `httproute.yaml` or `httproutes.yaml`, optional `netpol.yaml`, workload
  (`sts.yaml` or `deploy.yaml`), `svc.yaml`, `vpa.yaml`, optionally `tcproute.yaml`
  / `udproute.yaml` / `pvc.yaml`.
- catbox base: `httproutes.yaml`, `pvc.yaml`, `svc.yaml`, `vm.yaml` (KubeVirt
  VirtualMachine, no VPA — VMs are sized at the VM spec, not by VPA).
- qbittorrent base: `httproute.yaml`, `netpol.yaml`, `pvc.yaml`, `svc.yaml`,
  `vpa.yaml`.
- blackbox base: `blackbox-config` dir, `deploy.yaml`, `netpol.yaml`, `svc.yaml`,
  `vmprobe.yaml`, `vmrule.yaml`, `vpa.yaml` (probing app, so it carries a VMRule +
  VMProbe, not an HTTPRoute).
- inference / llama-cpp-rpc-head / llama-cpp base: `aiservicebackend.yaml`,
  `backend.yaml`, optional `backendsecuritypolicy.yaml`, `httproute.yaml`,
  optional `httproutefilter.yaml`, optional `llama-cpp-models-preset` +
  `llama-cpp-prefetch` (these are ConfigMap-style presets, not workload kinds),
  workload (`sts.yaml` or `deploy.yaml`), `svc.yaml`, optional `vmrule.yaml` +
  `vmservicescrape.yaml` (the head node ships monitoring; the worker does not).

The inference apps are the one place the "one workload kind per file" norm bends:
Envoy AI Gateway apps carry several CRDs in base (`AIServiceBackend`,
`Backend`, `HTTPRoute`, `HTTPRouteFilter`, `BackendSecurityPolicy`) because those
CRDs together describe one logical model endpoint. When in doubt, follow the
existing app in the same class rather than invent a new split.

One kind per file otherwise. The file is named by the short kube resource name:
`sts.yaml`, `deploy.yaml`, `svc.yaml`, `httproute.yaml`, `httproutes.yaml`,
`netpol.yaml`, `vpa.yaml`, `pvc.yaml`, `hr.yaml`, `ns.yaml`, `helmrepo.yaml`,
`cronjob.yaml`, `recurringjob.yaml`, `vmrule.yaml`, `vmservicescrape.yaml`,
`vmprobe.yaml`, `secret_provider_class.yaml`.

## `kustomization.yaml` in a base

A base kustomization lists its `resources:` sorted alphabetically, optionally
carries an `images:` block for tag rewrites, and is otherwise minimal. Observed
(metatube base, clusters/nishir/base, clusters/telsha/base):

```yaml
resources:
  - httproute.yaml
  - netpol.yaml
  - sts.yaml
  - svc.yaml
  - vpa.yaml
images:
  - name: metatube
    newName: ghcr.io/metatube-community/metatube-server
    newTag: 1.4.0@sha256:04d58879b76624e180cfdb24cde042b657189eabd3bd4cba851f1d56f7a5be82
```

Write `resources:` in sorted order. Do not write unsorted and promise to sort
later. Do not hand-edit generated kustomization YAML to fix sorting — fix the
generating source and re-render.

## App labels and selectors

Workloads carry the two-key `app.kubernetes.io` label set on pod template and
selector. Observed (metatube `sts.yaml`):

```yaml
selector:
  matchLabels:
    app.kubernetes.io/instance: metatube
    app.kubernetes.io/name: metatube
template:
  metadata:
    labels:
      app.kubernetes.io/instance: metatube
      app.kubernetes.io/name: metatube
```

The matching `svc.yaml` selector uses the same two keys. A Service also sets
`sessionAffinity: ClientIP` where appropriate and names its ports with
`appProtocol`.

The five-key `app.kubernetes.io` set (`component`, `instance`, `name`, `part-of`,
`version`) with `includeTemplates: true` is applied by overlay `labels:` blocks,
not by base. Observed (cluster entrypoint `clusters/nishir/overlays/tailnet/`):

```yaml
labels:
  - includeTemplates: true
    pairs:
      app.kubernetes.io/component: cluster
      app.kubernetes.io/instance: nishir
      app.kubernetes.io/name: nishir
      app.kubernetes.io/part-of: nishir-infrastructure
      app.kubernetes.io/version: 0.0.0
```

Keep `version` synced to the base image tag and bump it in the same PR as any
`newTag` change. Plain (non-tailnet) overlays are label-free by pattern. Base is
flavor-agnostic; labels that differ per cluster or per hostname belong in the
overlay that owns that flavor.

## Probes target the pod's own port

Liveness, readiness, and startup probes dial the container port by name
(`tcpSocket.port: http`), never a secondary-CNI or macvlan address. Kubelet dials
probes from the node network namespace, so a `host` address on br1/macvlan times
out forever and liveness restart-loops a healthy pod. Observed (metatube):

```yaml
ports:
  - name: http
    containerPort: 8080
livenessProbe:
  initialDelaySeconds: 60
  tcpSocket:
    port: http
  timeoutSeconds: 5
readinessProbe:
  initialDelaySeconds: 30
  tcpSocket:
    port: http
  timeoutSeconds: 5
startupProbe:
  failureThreshold: 180
  tcpSocket:
    port: http
  timeoutSeconds: 5
```

Named ports are preferred over numeric literals in probes so the same name appears
in the Service `targetPort`. A component that references a named probe port must
declare that `containerPort` in the same patch tree.

## Storage and PVCs

PVCs and volumeClaimTemplates carry their `storageClassName` directly in base —
overlays never patch the class. Observed (metatube `sts.yaml` volumeClaimTemplates):

```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      resources:
        requests:
          storage: 512Mi
      storageClassName: longhorn-standard
      volumeMode: Filesystem
      accessModes:
        - ReadWriteOncePod
```

Sizes grow to the next power of two above measured live usage, never speculative
multiples. Verify with `df`/`du` in-cluster before sizing an expansion.

Kustomize replaces VCT list entries: an overlay patch on `volumeClaimTemplates`
must restate every field; it does not field-merge with base. A partial overlay
patch silently drops fields. Verify with `kustomize build`, not the base file.

Standalone `pvc.yaml` (not inside a VCT) covers claims shared across workloads
(e.g. a syncthing shared data RWX claim under `clusters/<cluster>/base/`).

## Network: routes and the tailnet overlay

Ingress is an `HTTPRoute` in `apps/<app>/base/` whose `parentRefs` the overlay
patches. The tailnet overlay adds the per-hostname route and the
`GatewayClass`/`EnvoyProxy`/`Gateway` infrastructure lives in the tailnet overlay
tree, not in the app base. Observed pattern: an app base carries `httproute.yaml`;
the `nishir-tailnet` overlay patches `parentRefs` and adds hostnames.

Tailnet overlays append hostnames with a JSON6902 `op: add` on
`/spec/hostnames/-` with a scalar `value:`. Never pass a list value (that appends a
nested list) and never use `op: replace` on `/spec/hostnames` in tailnet overlays.

Cluster-local internal hosts are prefixed where needed (e.g. `grafana`). Hostname
split is strict: `overlays/<cluster>/` carries `*.i.shikanime.studio` ONLY;
`overlays/<cluster>-tailnet/` carries `*.taila659a.ts.net` ONLY. Never duplicate a
hostname across both.

## NetworkPolicy placement

Base keeps only transport-agnostic rules — typically a default-deny ingress unless
an intra-app flow exists. Observed (clusters/nishir/base/netpol.yaml): a
default-deny that allows only the `envoy-gateway-system` namespace.

```yaml
spec:
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: envoy-gateway-system
  podSelector: {}
  policyTypes:
    - Ingress
```

Exposure rules (envoy ingress, vmagent scrapes) are appended by inline JSON6902
`patches:` entries in the overlay that owns the exposure path. Netpol is enforced
cross-app, but envoy data-plane pods reach app pods even without a netpol ingress
entry.

## Infrastructure operators (HelmRelease pattern)

Most operators in `infrastructure/<operator>/` are Flux `HelmRelease` (`*hr.yaml`)
plus a `helmrepo.yaml` per source, with a base `ns.yaml` and optional `vpa.yaml`
and a `components/monitoring/` block. Observed trees: `cert-manager`,
`longhorn`, `gatekeeper`, `envoy-gateway`, `envoy-ai-gateway`, `tailscale`,
`trust-manager`, `victoria-metrics`, `grafana-operator`, `kubevirt`.

A multi-chart operator merges its charts into one multi-doc `hr.yaml` and deploys
into a matching `<operator>-system` namespace via `targetNamespace` (e.g.
`infrastructure/envoy/` → `envoy-gateway-system`).

KubeVirt is the documented exception: it has no official Helm chart, so it uses the
upstream operator + CR manifest pair instead of the `HelmRelease` pattern
(`infrastructure/kubevirt/base/kustomization.yaml` pulls the operator YAML from the
release URL and adds local `netpol.yaml` + `vpa.yaml`). KubeVirt requires
`/dev/kvm` on every node that should run VMs (nested virt if nodes are themselves
VMs), and the operator manifest already sets the `kubevirt-system` namespace to the
`privileged` Pod Security Standard.

## Configs (global, not app-tied)

`configs/<area>/` holds shared resources that are not tied to a single app:
storage classes, issuers, mutations, machine templates, recurring jobs. Observed:
`cert-manager`, `cluster-api`, `gatekeeper`, `longhorn`, `node-feature-discovery`,
`tailscale`. Structure mirrors the app shape: `base/` for shared resources,
`overlays/<cluster>/` for cluster-specific patches.

## Bootstraps (out-of-band install)

`bootstraps/<cluster>/` holds `HelmChart` resources that install the controllers
and operators the Kustomize overlays assume already exist. The overlays do not
install these — they assume them. Observed: `bootstraps/telsha/helmchart.yaml` +
`bootstraps/telsha/kustomization.yaml` (resources: `helmchart.yaml`).

## Secrets

The repo stays open-source: SOPS encrypts only selected fields via per-app
`encrypted_regex` rules defined in `flake.nix`; the rest of the file stays
plaintext. Encrypted files use the `*.enc.*` naming pattern (`.enc.env`,
`config.enc.yaml`, `LDAP-Auth.enc.xml`, including leading-dot files). Secret files
live in a subfolder named after the secret (e.g. `discord-webhook/.enc.env`,
`receiver-token/.enc.env`), wired into Flux `secretGenerator` entries by the
cluster overlay. Decrypted outputs are derived by stripping `.enc.` from the
filename; never commit them — change the encrypted source instead.

Editing `*.enc.*` files, their `encrypted_regex`, and their recipient sets is
`sops-authoring`, not this skill. A manifest PR that adds a `secretGenerator`
entry and its `.enc.*` file is two concerns: the manifest structure (this skill)
and the encrypted file edit (sops-authoring).

## Overlays: patches, components, and inheritance

### Overlay inheritance

`overlays/<cluster>-<overlay>/` (e.g. `nishir-tailnet`) builds on
`resources: - ../<cluster>` — cluster-wide transforms set in
`overlays/<cluster>/` apply to every overlay flavor of that cluster. Transforms
needed on all clusters belong in base; transforms only for one flavor go in that
flavor's overlay.

### Patch placement

Every patch to a core kube resource (StatefulSet, Deployment, Service, …) is a
strategic-merge file `patch-<resource>.yaml` listed under `patches:`. JSON6902
inline entries (`patch: |-` + `target:`) are for CRDs and specific cases the
strategic merge cannot express: list appends like `env/-`, keyed lists without
merge keys, and hostname appends.

### Kustomize v5 facts

- A JSON6902 patch FILE must be a single ops-list doc. Multidoc `{patch, target}`
  files fail to parse; multidoc ops-lists are order-dependent.
- `add` on an existing object member acts as replace (RFC 6902).
- `op: add` on a list path appends. Use `path: /spec/hostnames/-` with a scalar
  `value:` to append a hostname; a list value appends a nested list (wrong).
- A component referencing a named probe port must declare that `containerPort` in
  the same patch tree.

## Don't add (YAGNI catalog for manifests)

- **A second kustomization layer that only re-lists the same resources.** One
  kustomization per logical tree is the unit; a pass-through overlay that exists
  "in case" is a future merge conflict. Delete it.
- **A ConfigMap/Secret that duplicates what the app already reads from env or a
  mounted secret.** If the value is already available to the container, do not add
  a second delivery path.
- **A VPA in a tree that already has one.** Every app base already includes
  `vpa.yaml`; a second is drift.
- **A probe on a macvlan/br1 host address.** It will look green in a local test
  and restart-loop in-cluster. Use the named container port.
- **A label on base that belongs in an overlay.** Base is flavor-agnostic; labels
  that differ per cluster or per hostname belong in the overlay.
- **A new abstraction (shared base, common component, helper kustomization) when
  the existing per-app tree already covers the case.** Each app is its own tree;
  do not invent a shared `apps/common/` base to avoid repeating two lines.
- **An overlay for a cluster flavor that no app uses yet.** Add the overlay when
  the first app needs it, not ahead of demand.

The shared rule across manifests and Nix authoring: if the default already does
it, do not add a layer. A manifest pattern that exists three times in the repo is
the pattern; a fourth copy is normal, a shared abstraction invented to "avoid
repeating it" is usually premature.

## Verification

```bash
# kustomize builds the tree you touched
kustomize build clusters/<cluster>/overlays/<overlay>
kustomize build apps/<app>/overlays/<cluster>

# resources list is sorted
grep '^  - ' apps/<app>/base/kustomization.yaml

# one kind per file, named by short resource name
ls apps/<app>/base/ | grep -E '\.yaml$'

# probes target a named container port, not a host address
grep -A3 'livenessProbe\|readinessProbe' apps/<app>/base/sts.yaml

# tailnet hostnames appended with scalar add, not list replace
grep -E 'op: (add|replace)' apps/<app>/overlays/*-tailnet/*.yaml

# staged diff is only the yaml you intended
jj diff --git | grep -E '^diff --git a/.*\.yaml'
```

## Gotchas

The detail lives in the sections above — this is the one-liner version:

- **Read rendered output, not source.** `kustomize build` is the verification;
  GitHub's web diff pads context and a partial overlay patch can look fine in the
  base file while silently dropping fields in the composed tree.
- **VCT list entries are replaced, not merged.** An overlay patch on
  `volumeClaimTemplates` (or any list) must restate the whole entry; a partial
  patch drops fields silently.
- **JSON6902 patch files are single-doc.** Multidoc `{patch, target}` files fail
  to parse.
- **`add` on an existing member is replace** (RFC 6902); tailnet hostnames append
  with `op: add` on `/spec/hostnames/-` with a scalar `value:` — a list value
  nests, `replace` on `/spec/hostnames` clobbers the list.
- **A live object with no manifest in this repo is drift.** Delete it; never build
  on it. Flux reverts a live `kubectl patch` at the next reconcile (suspend the
  Kustomization only for interim relief).
- **One overlay building is not the composited tree building.** Verify the build
  entrypoint (`clusters/<cluster>/overlays/<overlay>/kustomization.yaml`) when the
  change reaches the composed tree.

The longer treatments live in `## Overlays: patches, components, and inheritance`,
`## Storage and PVCs`, `## Network: routes and the tailnet overlay`, and
`## Verification`.

## See also

- `sks-delegate` — isolate this unit in a fresh jj workspace before editing.
- `sks-commit` — commit style for manifests: plain-text capitalized title, no
  conventional prefix, `Signed-off-by:` + `Co-authored-by: Automata` trailers,
  `gitlint` CC1 enforces `Signed-off-by`.
- `sks-dev-workflow` — branch / push / landing; `nix fmt` caveat for the repo's
  markdown wrapping, and `kustomize build` as the verification gate.
- `sops-secrets-authoring` — edit the `*.enc.*` secret files this manifest references.
- `sks-pr-review` — reviewer lens that enforces YAGNI and the repo conventions on
  the PR.
