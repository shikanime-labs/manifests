# gitea-mirror

Auto-mirror of GitHub orgs/repos into Forgejo: a single-replica
StatefulSet polling `GITEA_URL` (forgejo.shikanime.svc.cluster.local)
into the `infinity-blackmirror` organization, with `AUTO_MIRROR_REPOS`,
`MIRROR_ISSUES`/`LABELS`/`MILESTONES`/`PULL_REQUESTS`/`RELEASES`/`WIKI`
and friends enabled. Serves a small web UI on :80 (pod port 4321) and
stores state on a 1Gi PVC; the NetworkPolicy admits HTTP only from
`tailscale-system`.

## Layout

- `base/` — sts.yaml (mirror env, :4321), svc.yaml (http :80),
  pvc.yaml (1Gi), netpol.yaml, vpa.yaml.
- `overlays/nishir/` — PVC patch only.
- `overlays/nishir-tailnet/` — Tailscale Ingress, netpol/sts patches
  (Tailscale header auth, `BETTER_AUTH_*`), secretGenerator from
  `gitea-mirror/.enc.env`.
