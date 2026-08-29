<!-- owner: shikanime | zone: internal | purpose: bootstrap, render, apply, add an app -->

# Runbook

## Bootstrap controllers

The Kustomize overlays assume controllers/operators already exist. Install
them out-of-band from `bootstraps/` (Flux `HelmChart` resources, e.g.
`bootstraps/telsha/helmchart.yaml`). Longhorn, cert-manager, Tailscale
Operator, KubeVirt, and the VPA controller must be present before apps apply.

## Render and apply

Flux reconciles the cluster from the Git source; no manual `kubectl apply` is
needed for tracked resources. To preview locally:

```sh
skaffold render -p nishir-tailnet
skaffold render -p telsha-tailnet
```

## Add an app

1. `apps/<app>/base/` — `Deployment`/`StatefulSet`, `Service`, `Ingress`,
   `vpa.yaml`, `pvc.yaml` (one kind per file, named
   `<short-kube-resource-name>.yaml`).
2. `apps/<app>/overlays/<cluster>/` — cluster patches and `PVC`.
3. `clusters/<cluster>/overlays/<overlay>/` — compose the app overlay in.
4. For tailnet ingress, set `ingressClassName: tailscale` + annotations in the
   `*-tailnet` overlay.

## Branch protection

- 1 approving review, linear history, signed commits, squash+rebase only.
- Plain-text capitalized title; `gitlint` enforced.
