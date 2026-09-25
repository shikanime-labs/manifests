---
name: overlay-authoring
description: Use when authoring or editing kustomization overlays, apps, or components in this repo.
version: 0.1.0
author: Shikanime Deva, Hermes Agent
license: Apache-2.0
platforms: [linux, macos]
metadata:
  hermes:
    tags: [kustomize, kubernetes, gitops, overlays, nishir]
    related_skills: [flux-ks-recovery, workload-migration]
---

# Overlay Authoring

AGENTS.md owns the layout and overlay conventions; this skill owns the
failure modes that bite while applying them. Read AGENTS.md first — everything
below assumes it.

## When to Use

- Adding a new app (base + overlays + `ks.yaml` wiring).
- Editing any `apps/`, `infrastructure/`, `configs/`, or `clusters/`
  kustomization or its patches.
- Diagnosing "rendered fine locally, CI red" or "merged, nothing deployed".

## Render the deploy path, not the overlay name

A Flux Kustomization's `spec.path` frequently points at the `-tailnet`
aggregate while the KS name mirrors the plain overlay:

```bash
kubectl -n flux-system get kustomization <ks> \
  -o jsonpath='{.spec.path}'
```

`kustomize build overlays/<plain>` passing proves nothing about the deploy
path — always render THAT path locally. Same for health checks: a
`spec.healthChecks` entry naming a `kind` the workload no longer has (common
after a Deployment→StatefulSet migration) times out every reconcile while the
real workload runs healthy. The fix lives in the owning `ks.yaml`.

## Kustomize v5 patch rules

- A JSON6902 patch **file** is a single ops-list document. Multidoc
  `{patch,target}` files fail to parse; multidoc ops-lists are
  order-dependent.
- `add` on an existing object member acts as replace (RFC 6902).
- An overlay VCT patch must **restate every field** — Kustomize replaces
  list entries, it never field-merges with base. A patch adding only
  `storageClassName` silently drops `resources.requests.storage` and
  `kubectl kustomize` still exits 0.
- A component referencing a named probe port must declare that
  `containerPort` in the same patch tree.
- Core kube resources take strategic-merge files `patch-<resource>.yaml`
  under `patches:`; inline JSON6902 is for CRDs and list appends (`env/-`)
  SMP cannot express. `namereference.yaml` entries are only for CRDs —
  Kustomize rewrites generated-Secret references on core resources natively.
- Removing `disableNameSuffixHash` from a secretGenerator changes every
  rendered generated name — check nothing references the plain name.

## Tailnet gotchas

- Hostname append is a scalar: `op: add` on `path: /spec/hostnames/-` with
  `value:`. A list value appends a nested list; `replace` on
  `/spec/hostnames` clobbers the cluster flavor. Never either.
- The five-key label set carries `version` synced to the base image tag —
  bump it in the same PR as any `newTag` change.
- A `labels:` transformer with `includeTemplates: true` force-writes its
  pairs onto every pod template. Distinguish a worker from the parent app
  with a key OUTSIDE the transformer's pairs and select on that in the
  Service/selector — otherwise `spec.selector does not match template
  labels` at create time, a class of bug renders valid and only fails at
  apply.
- Route-less apps (headless Service, DNS-only consumers) need no
  `*-tailnet` overlay; their labels live in `overlays/<cluster>/` — the
  terminal overlay the Flux path targets.

## Netpol placement

Base keeps transport-agnostic rules only (deny-all ingress unless an
intra-app flow exists). Exposure rules are appended by inline JSON6902
entries in the overlay owning the exposure path:

- vmagent scrape grants: port NAME must equal the VMServiceScrape's target
  svc port — a policy admitting `metrics` against a scrape targeting `http`
  is a dead scrape despite looking permissive.
- Split netpol entries per peer: one `ports` list is shared across ALL
  `from` peers of an entry; mixing app peers with vmagent leaks ports.
- No VMServiceScrape ⇒ no vmagent entry at all; vestigial grants get
  deleted.
- Envoy data-plane pods reach app pods even without a netpol ingress entry,
  and `kubectl port-forward` bypasses netpol entirely — neither is proof of
  netpol correctness.

## Storage and sizing

- VPA: every app base carries `vpa.yaml`. Floors/caps decisions:
  `vpa-memory-floor-audit`.
- PVC/PV sizes grow to the next power of two above measured live usage —
  verify with `df`/`du` in-cluster before sizing an expansion; never
  speculative multiples.
- Storage class changes and PVC-to-VCT conversions are migrations:
  `workload-migration`.

## New app recipe

Worked pattern (each new app follows it; see `references/new-app-recipe.md`
for a filled example):

1. `apps/<app>/base/` — one kind per file named
   `<short-kube-resource-name>.yaml` (`deploy.yaml`/`sts.yaml`, `svc.yaml`,
   `vpa.yaml`, `netpol.yaml`, `pvc.yaml` as needed), `resources:` sorted.
2. Components (`components/tls/`, `components/monitoring/`) — each a
   kustomize Component; the cluster overlay composes them.
3. Overlays per cluster flavor; tailnet flavors build on
   `resources: [- ../<cluster>]`.
4. Wire the Flux KS (`clusters/<cluster>/overlays/<overlay>/ks.yaml`) with
   health checks matching the REAL workload kind.
5. Render battery before shipping: every touched overlay + the cluster
   aggregate + `skaffold` profiles (`nishir-tailnet`, `telsha-tailnet`).

## No dangling files

Every file must be referenced by its kustomization (`path:` / `files:` /
`envs:` / inline). After deleting a resource, grep the kustomization — an
unreferenced file is dead weight, and CI treefmt still formats it.

## Verification

```bash
# fleet sweep: every kustomization renders
find apps infrastructure configs clusters -name kustomization.yaml | \
  while read -r k; do kustomize build "$(dirname "$k")" >/dev/null || \
  echo "FAIL $(dirname "$k")"; done
# scoped format — NEVER a whole-tree `nix fmt` (~64 unrelated files dirty)
nix fmt apps/<app>
git status --short   # restore anything outside your change-set
```

Rendered assertions worth scripting for storage/selector changes: rendered
VCT spec field-by-field, `selector` ⊆ `template.labels` per workload, zero
references to dropped names (stream-parse multi-doc YAML with
`safe_load_all`).
