# syncthing-config

One-shot Job that pushes the LDAP auth configuration to Syncthing's REST API
(`PUT`-semantics via `PATCH` on `/rest/config/gui` and `/rest/config/ldap`),
keeping the auth config in VCS the same way `qBittorrent.conf` and Jellyfin's
`LDAP-Auth.xml` are. Idempotent: safe to re-run (`kubectl -n shikanime delete
job syncthing-config` — Flux recreates it on every sync).

Auth change rationale: #2261 replaced the Envoy OIDC layer with Syncthing's
native LDAP support. The LLDAP `syncthing` group gates GUI login.

## Layout

- `base/` — Job (curlimages/curl) that waits for the Syncthing API, then
  applies `authMode: ldap` + the LLDAP bind pattern/group filter.
- `overlays/nishir/` — namespace only.

The Job reads the API key from Secret `syncthing-config-apikey` (`key` entry).
