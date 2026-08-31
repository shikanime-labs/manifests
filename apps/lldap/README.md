# lldap

LDAP identity store for the platform: a single-replica StatefulSet serving LDAP
on :3890 with env from the SOPS-encrypted `lldap` Secret (`lldap/.enc.env`).
Headless Service (no ClusterIP), data on a ReadWriteOncePod volumeClaimTemplate,
and a NetworkPolicy that admits only the ldap and ui ports.

The web UI (port 17170) is exposed over the tailnet at
`https://lldap.i.shikanime.studio` via a BYOD Envoy Gateway (GatewayClass +
EnvoyProxy + Gateway in the tailnet overlay), with TLS from the
`studio-shikanime-i-lldap` cert-manager Certificate.

## Layout

- `base/` — sts.yaml (3890 ldap + 17170 ui, 512Mi data volume claim),
  svc.yaml (headless, ldap + ui), httproute.yaml, netpol.yaml, vpa.yaml.
- `components/tls/` — adds an ldaps port (6360) to the Service and
  NetworkPolicy, patches the STS with serving certs.
- `overlays/nishir/` — cluster CA cert, tls component, PVC patch,
  secretGenerator from `lldap/.enc.env`.
- `overlays/nishir-tailnet/` — BYOD Envoy Gateway (gatewayclass, envoyproxy,
  gateway, httproute-redirect) exposing the UI at `lldap.i.shikanime.studio`;
  inherits `../nishir`.
