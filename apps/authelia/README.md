# authelia

Authentication/authorization server and OIDC 1.0 identity provider for the
nishir platform, replacing dex. A three-replica Deployment running
`authelia/authelia` (4.39.20) serving HTTPS :9091 with the cluster CA cert
(via the `tls` component) plus a Prometheus exporter on :9959. Configuration
is the SOPS-encrypted `configuration.enc.yaml`, emitted as `configuration.yaml`, mounted read-only at
`/config`; state lives in Postgres (`authelia-postgres`) and sessions in
Valkey (`authelia-valkey`).

OIDC clients are migrated 1:1 from dex (forgejo, gitea-mirror, synapse,
hermes-agent, vaultwarden, immich, copyparty); client secrets are stored as
PBKDF2-SHA512 digests. The LDAP backend is lldap
(`lldap.shikanime.svc.cluster.local:6360`).

Exposed at `accounts.i.shikanime.studio` and `accounts.taila659a.ts.net`
via the per-app BYOD Envoy gateway (same pattern as lldap/dex). NOTE: when
re-encrypting, the `encrypted_regex` collaterally matches `server.tls.key`
(a plaintext path) — Flux decrypts transparently, so this is harmless.

## Layout

- `base/` — sts.yaml (config Secret volume + sqlite PVC), svc.yaml (http,
  metrics), netpol.yaml, vpa.yaml.
- `components/monitoring/` — vmservicescrape for the metrics port.
- `components/tls/` — patches the Deployment (serving certs) and adds an https
  Service port.
- `overlays/nishir/` — cluster CA cert, tls component, secretGenerator
  feeding `authelia` from `authelia/configuration.enc.yaml` as `configuration.yaml`.
- `overlays/nishir-tailnet/` — BYOD tailnet gateway on
  `accounts.taila659a.ts.net` plus monitoring component.

## Cutover note

2FA/TOTP device registrations and other user DB content live in the old
sqlite (`/config/db.sqlite3` on the PVC). They do NOT migrate automatically:
either export/import the sqlite content into Postgres before flipping the
storage backend, or users re-enroll.
scaling follows once the cutover is verified live.
