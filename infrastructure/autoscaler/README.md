# VPA (Vertical Pod Autoscaler)

The Vertical Pod Autoscaler (VPA) component is deployed in the
`autoscaler-system` namespace using FluxCD-native manifests instead of the
upstream `fairwinds/vpa` Helm chart.

## Migration

Previously VPA was installed via a FluxCD `HelmRelease` pointing at
`fairwinds-stable/vpa` (chart version 4.11.0). The migration replaces the
HelmRelease with inline YAML manifests so that:

- No third-party Helm chart dependency is required.
- All VPA components (admission controller, recommender, updater) are rendered
  as direct Kubernetes manifests under FluxCD management.
- CRDs (`VerticalPodAutoscaler`, `VerticalPodAutoscalerCheckpoint`) are
  installed from the official VPA project manifests.

## Structure

```
infrastructure/autoscaler/
  base/
    kustomization.yaml   # Resources: ns, flux-vpa, vpa-crd
    ns.yaml              # Namespace + PodSecurity labels
    flux-vpa.yaml        # 29 native resources (SAs, RBAC, PDBs, Deployments, Service, Webhook)
    vpa-crd.yaml         # VPA CRDs (VerticalPodAutoscaler + Checkpoint)
  components/
    monitoring/          # VMServiceScrape for Prometheus metrics
  overlays/
    nishir/              # Issuer reference: nishir
      kustomization.yaml
      cert.yaml          # Certificate for vpa-webhook (cert-manager)
    telsha/              # Issuer reference: telsha
      kustomization.yaml
      cert.yaml          # Certificate for vpa-webhook (cert-manager)
```

## FluxCD-specific Patches

The following patches are applied relative to the upstream Helm chart output:

1. **Certificate generation disabled** — `generateCertificate: false` in the
   chart values. TLS certificates are instead issued by cert-manager via the
   `vpa-tls-secret` Certificate resource in each overlay. This is annotated on
   the `MutatingWebhookConfiguration` with
   `cert-manager.io/inject-ca-from: autoscaler-system/vpa-tls-secret`.

2. **Replica count increased** — All three components (admission controller,
   recommender, updater) run with `replicaCount: 2` for high availability.

3. **PodDisruptionBudgets** — Each component has a PDB with `maxUnavailable: 1`
   to ensure graceful rolling updates.

4. **Health check target** — The FluxCD `Kustomization` CR
   (`clusters/<cluster>/components/autoscaler/ks.yaml`) health-checks the
   `vpa-admission-controller` Deployment directly instead of the HelmRelease,
   since the HelmRelease no longer exists after migration.

5. **Secrets** — No Helm-managed secrets are created. The TLS secret
   (`vpa-tls-secret`) is managed by cert-manager.

## Verification Steps

1. Build the kustomize overlay:
   ```bash
   kustomize build clusters/telsha/overlays/tailnet
   kustomize build clusters/nishir/overlays/tailnet
   ```

2. Validate all manifests with kubeconform:
   ```bash
   kustomize build clusters/telsha/overlays/tailnet | kubeconform -
   kustomize build clusters/nishir/overlays/tailnet | kubeconform -
   ```

3. Verify CRDs install correctly:
   ```bash
   kubectl apply --dry-run=client -f infrastructure/autoscaler/base/vpa-crd.yaml
   ```

4. Verify the FluxCD Kustomization health check:
   ```bash
   kubectl get kustomization infrastructure-autoscaler -n flux-system -o yaml
   ```

5. Confirm the webhook is served by the admission controller:
   ```bash
   kubectl get deploy vpa-admission-controller -n autoscaler-system
   kubectl get svc vpa-webhook -n autoscaler-system
   ```
