---
name: flux-ks-recovery
description: Use when a Flux Kustomization or HelmRelease stops rolling out, or a reconcile or health check fails in this fleet.
version: 0.1.0
author: Shikanime Deva, Hermes Agent
license: Apache-2.0
platforms: [linux, macos]
metadata:
  hermes:
    tags: [flux, kustomization, health-check, reconcile, nishir]
    related_skills: [overlay-authoring, workload-migration]
---

# Flux Kustomization Recovery

A wedged KS is not just its own app: it stops every later change to that app
from rolling out, so an unrelated urgent fix "merges but never lands". When
something is not taking effect, check the owning KS is `Ready=True` FIRST,
before re-debugging the fix.

## Procedure

1. **Read the real build path, never assume it matches the KS name**
   (`kubectl -n flux-system get kustomization <ks> -o jsonpath='{.spec.path}'`)
   — render THAT path locally; the plain overlay rendering green proves
   nothing.
2. **Read conditions fresh each cycle.** A wedged KS carries stale messages
   from earlier failed revisions; the top `Reconciling` line names the
   revision actually being attempted.

   ```bash
   kubectl get kustomization <ks> -n flux-system -o jsonpath \
     '{range .status.conditions[*]}{.type}={.status}: {.message}{"\n"}{end}'
   ```

3. **Check the Git source revision is current** —
   `gitrepository flux-system .status.artifact.revision` vs the repo's main
   SHA — before blaming the KS.
4. **Force a cycle** with the annotation (the `flux` CLI can hang here; the
   annotation is equivalent):

   ```bash
   kubectl annotate kustomization <ks> -n flux-system \
     reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
   ```

5. **Wait out the health-check window.** A failed health check runs to its
   full timeout (default ~9m30s) before the next revision is attempted;
   annotating during the window queues, it does not cancel. Budget the wait
   before concluding a fix "did not work".

## Failure-mode table

| Signature | Cause | Fix |
| --- | --- | --- |
| `health check failed ... Deployment/x` while workload is a STS | `ks.yaml` health-check `kind` drift | fix the kind in the owning `ks.yaml` |
| `health check failed ... VirtualMachine status 'InProgress'` | KubeVirt `RestartRequired` (see `kubevirt-restart-required-recovery`) | `virtctl restart <vm>` |
| `status 'Failed'` on a StatefulSet, KS pinned at old revision | app pod crash-looping pins `lastAppliedRevision` | fix the config AND let the pod start once (delete the pod to pick up new Secret) — the KS will not advance while the target STS keeps failing |
| `fatal ... errors loading the configuration` | bad config, still on old revision | fix config |
| `fatal ... startup checks` + LDAP/SMTP/DNS timeouts | config PARSED; egress/DNS broken | test DNS/egress from a probe pod; check CoreDNS `forward` per-node resolvers |
| `dependency not up to date` forever | a `dependsOn` dependency has `suspend: true` | unsuspend or restructure; a suspended KS never advances `lastAppliedRevision` |
| dry-run `Invalid` on an STS VCT/immutable field | git drifts from live (VCT size, storage class) | see `workload-migration`; never revert git to match live |

## Gotchas

- `suspend: true` freezes `lastAppliedRevision` permanently and blocks every
  dependent KS (`dependsOn`) — even when the suspended app's workload is
  fine. Prefer manifest-level suspension (`replicas: 0`) over
  `spec.suspend`.
- After a suspended KS is resumed, the first `ReconciliationFailed` may
  carry the OLD diff (resume raced the fix) — force `requestedAt` and judge
  only by fresh `lastTransitionTime` + `lastAppliedRevision`.
- `lastAppliedRevision` stale + `Reconciling` at an older revision means the
  new revision has NOT been attempted yet — do not debug its content until
  Flux actually tries it.
- Parallel actors mutate live state between your reads. Before
  implementing: `jj git fetch`, re-read the exact file at `main@origin`, and
  `gh pr list` for racing branches — a sibling unit may have landed the same
  fix (or shifted the VCT you just measured).
- In-cluster Service URLs in CRs (VLAgent remoteWrite, vmalert datasources):
  verify the Service port from `kubectl get svc` before writing the URL —
  kustomize build and server dry-run prove shape only, never connectivity.
  After rollout, read the workload's own logs for delivery errors, then
  exercise the receiving API (VictoriaLogs `| count()` > 0).
- `kubectl port-forward` bypasses netpol — a successful port-forward probe
  is not netpol proof.

## Verification

`flux get kustomization <ks> -n flux-system` → `READY=True Healthy=True`;
`lastAppliedRevision` equals the intended merge SHA.
