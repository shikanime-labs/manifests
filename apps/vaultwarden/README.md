# vaultwarden

Bitwarden-compatible password manager: a single-replica StatefulSet
serving HTTP on :80 with env from the SOPS-encrypted `vaultwarden`
Secret. Data lives on the `vaultwarden-data` PVC (1Gi,
ReadWriteOncePod); the NetworkPolicy admits HTTP only from the
`tailscale-system` namespace.

## Layout

- `base/` — sts.yaml, svc.yaml (http :80), pvc.yaml (1Gi),
  netpol.yaml, vpa.yaml.
- `components/tls/` — patches the STS and adds an https Service port.
- `overlays/nishir/` — cluster CA cert, tls component, PVC patch,
  secretGenerator from `vaultwarden/.enc.env`.
- `overlays/nishir-tailnet/` — Tailscale Ingress, netpol patch.
