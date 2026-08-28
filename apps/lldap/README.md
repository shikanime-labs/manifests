# lldap

LDAP identity store for the platform: a single-replica StatefulSet serving LDAP
on :3890 with env from the SOPS-encrypted `lldap` Secret (`lldap/.enc.env`).
Headless Service (no ClusterIP), data on a ReadWriteOncePod volumeClaimTemplate,
and a NetworkPolicy that admits only the ldap port.

## Layout

- `base/` — sts.yaml (3890, 512Mi data volume claim), svc.yaml (headless, ldap),
  netpol.yaml, vpa.yaml.
- `components/tls/` — adds an ldaps port (6360) to the Service and
  NetworkPolicy, patches the STS with serving certs.
- `overlays/nishir/` — cluster CA cert, tls component, PVC patch,
  secretGenerator from `lldap/.enc.env`.
- `overlays/nishir-tailnet/` — labels only; inherits `../nishir`.
