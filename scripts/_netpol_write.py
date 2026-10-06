import os

path = r"D:\Source\Repos\GitHub.com\shikanime\manifests\docs\migration\netpol-audit.md"
os.makedirs(os.path.dirname(path), exist_ok=True)

content = """# NetworkPolicy Audit for Cilium Compatibility

**Date:** 2026-06-11
**Cluster:** nishir (RKE2 v1.34.7)
**Scope:** All NetworkPolicy resources in manifests repo
**Total NetworkPolicies reviewed:** 55

---

## Executive Summary

All 55 NetworkPolicies use the standard `networking.k8s.io/v1` API. Zero Calico-specific CRDs found. Zero references to `projectcalico.org`.

**Compatibility verdict: FULL -- all policies are natively supported by Cilium without modification.**

---

## Calico CRD Check

No Calico CRDs found: no GlobalNetworkPolicy, NetworkSet, HostEndpoint, IPPool, BGPPeer, FelixConfiguration, or any `projectcalico.org` API references.

**No CiliumNetworkPolicy conversion required.**

---

## Inventory (55 NetworkPolicies)

### Cluster-Scoped (1)

| File | Name | Types |
|---|---|---|
| `clusters/nishir/base/netpol.yaml` | `default` (ns: shikanime) | Ingress |

### App Base Policies (27)

| # | File | Name | Allowed From | Ports |
|---|---|---|---|---|
| 1 | `apps/bazarr/base/netpol.yaml` | `bazarr` | prowlarr | http |
| 2 | `apps/chrome/base/netpol.yaml` | `chrome` | hermes-agent | cdp |
| 3 | `apps/forgejo/base/netpol.yaml` | `forgejo` | gitea-mirror | http, ssh |
| 4 | `apps/hermes-agent/gateway/components/api/netpol.yaml` | `hermes-agent-gateway` | hermes-agent-dashboard (ns+pod) | http |
| 5 | `apps/honcho/base/netpol.yaml` | `honcho` | hermes-agent | http |
| 6 | `apps/honcho-postgres/base/netpol.yaml` | `honcho-postgres` | honcho | postgres |
| 7 | `apps/jellyfin/base/netpol.yaml` | `jellyfin` | lidarr, radarr, seerr, sonarr, whisparr | https |
| 8 | `apps/mautrix/*/base/netpol.yaml` (x8) | `mautrix-*` | synapse (+ synapse-proxy for discord) | http |
| 9 | `apps/metatube/base/netpol.yaml` | `metatube` | jellyfin | http |
| 10 | `apps/prowlarr/base/netpol.yaml` | `prowlarr-allow-apps` | lidarr, sonarr, radarr, whisparr | https |
| 11 | `apps/qbittorrent/base/netpol.yaml` | `qbittorrent` | servarr + qbittorrent-cleanup | https |
| 12 | `apps/seerr/base/netpol.yaml` | `seerr` | jellyfin | http |
| 13 | `apps/servarr/lidarr/base/netpol.yaml` | `lidarr` | prowlarr | https |
| 14 | `apps/servarr/radarr/base/netpol.yaml` | `radarr` | bazarr, jellyfin, seerr, prowlarr | https |
| 15 | `apps/servarr/sonarr/base/netpol.yaml` | `sonarr` | bazarr, jellyfin, seerr, prowlarr | https |
| 16 | `apps/servarr/whisparr/base/netpol.yaml` | `whisparr` | prowlarr | https |
| 17 | `apps/synapse/base/netpol.yaml` | `synapse` | all mautrix + synapse-proxy | https |
| 18 | `apps/synapse-proxy/base/netpol.yaml` | `synapse-proxy` | Ingress: synapse. Egress: synapse, mautrix-discord, kube-dns | https, http, 53 |

### App Overlay -- nishir-tailnet (27)

All follow pattern: allow from `tailscale-system` namespace via namespaceSelector.

| # | File | Name | Ports |
|---|---|---|---|
| 1 | `apps/bazarr/overlays/nishir-tailnet/netpol.yaml` | `bazarr-tailscale` | http |
| 2 | `apps/copyparty/overlays/nishir-tailnet/netpol.yaml` | `copyparty-tailscale` | http, ftp-control, ftp-data-12000..12099, ftps |
| 3 | `apps/forgejo/overlays/nishir-tailnet/netpol.yaml` | `forgejo-tailscale` | http, ssh |
| 4 | `apps/gitea-mirror/overlays/nishir-tailnet/netpol.yaml` | `gitea-mirror-tailscale` | http |
| 5 | `apps/hermes-agent/dashboard/overlays/nishir-tailnet/netpol.yaml` | `hermes-agent-dashboard-tailscale` | http |
| 6 | `apps/hermes-agent/gateway/overlays/nishir-tailnet/netpol.yaml` | `hermes-agent-gateway-tailscale` | http, webhook |
| 7 | `apps/honcho/overlays/nishir-tailnet/netpol.yaml` | `honcho-tailscale` | http |
| 8 | `apps/jellyfin/overlays/nishir-tailnet/netpol.yaml` | `jellyfin-tailscale` | https |
| 9-16 | `apps/mautrix/*/overlays/nishir-tailnet/netpol.yaml` (x8) | `mautrix-*-tailscale` | http |
| 17 | `apps/prowlarr/overlays/nishir-tailnet/netpol.yaml` | `prowlarr-tailscale` | https |
| 18 | `apps/qbittorrent/overlays/nishir-tailnet/netpol.yaml` | `qbittorrent-tailscale` | https, bittorrent/tcp, bittorrent-udp/udp |
| 19 | `apps/seerr/overlays/nishir-tailnet/netpol.yaml` | `seerr-tailscale` | http |
| 20 | `apps/servarr/lidarr/overlays/nishir-tailnet/netpol.yaml` | `lidarr-tailscale` | https |
| 21 | `apps/servarr/radarr/overlays/nishir-tailnet/netpol.yaml` | `radarr-tailscale` | https |
| 22 | `apps/servarr/sonarr/overlays/nishir-tailnet/netpol.yaml` | `sonarr-tailscale` | https |
| 23 | `apps/servarr/whisparr/overlays/nishir-tailnet/netpol.yaml` | `whisparr-tailscale` | https |
| 24 | `apps/synapse/overlays/nishir-tailnet/netpol.yaml` | `synapse-tailscale` | https |
| 25 | `apps/synapse-proxy/overlays/nishir-tailnet/netpol.yaml` | `synapse-proxy-tailscale` | https (+ same egress) |
| 26 | `apps/syncthing/overlays/nishir-tailnet/netpol.yaml` | `syncthing-tailscale` | http |
| 27 | `apps/vaultwarden/overlays/nishir-tailnet/netpol.yaml` | `vaultwarden-tailscale` | https |

---

## Cilium Compatibility

### API: PASS
All 55 use `apiVersion: networking.k8s.io/v1` / `kind: NetworkPolicy`. Cilium supports these natively.

### Selectors: PASS
- `podSelector.matchLabels` (all 55)
- `namespaceSelector.matchLabels` (tailscale overlays + egress)
- Combined `namespaceSelector` + `podSelector` (hermes-agent-gateway api netpol)
- Empty `podSelector: {}` (cluster default)

### Ports: PASS
All named ports. Cilium supports named ports.

### Protocols: PASS
Default TCP. Explicit UDP in qbittorrent-udp and synapse-proxy DNS.

---

## Observations (Non-Blocking)

1. **No default-deny egress** -- cluster base policy only restricts ingress. Optional to add under Cilium.

2. **Unusual namespaceSelector in hermes-agent-gateway** -- uses `app.kubernetes.io/instance` and `app.kubernetes.io/name` labels instead of `kubernetes.io/metadata.name`. Verify the `hermes-agent-dashboard` namespace has these labels.

3. **Broad DNS egress** -- synapse-proxy allows port 53 to entire kube-system namespace. Functional but wide scope.

4. **Missing base netpols** -- catbox, syncthing, vaultwarden have no base netpol (only tailscale overlays).

---

## Service Dependency Graph

```
prowlarr --> bazarr, lidarr, radarr, sonarr, whisparr
hermes-agent --> chrome, honcho
hermes-agent-dashboard --> hermes-agent-gateway
honcho --> honcho-postgres
jellyfin --> metatube, seerr
servarr apps --> jellyfin, qbittorrent
synapse --> all mautrix bridges, synapse-proxy
all mautrix bridges --> synapse
synapse-proxy --> synapse (ingress + egress)
synapse-proxy --> mautrix-discord (egress)
gitea-mirror --> forgejo
tailscale-system/* --> all exposed apps (tailscale overlays)
kube-system:53 <-- synapse-proxy (DNS egress)
```

---

## Migration Checklist

- [x] No Calico-specific CRDs found
- [x] All policies use standard `networking.k8s.io/v1`
- [x] No `projectcalico.org` API references
- [x] All selectors are standard Kubernetes
- [x] Named ports used consistently
- [ ] Verify hermes-agent-dashboard namespace has app.kubernetes.io labels
- [ ] Consider default-deny egress policy (optional)
- [ ] Verify RKE2-managed policies don't conflict
- [ ] Test Cilium enforcement in non-production first
"""

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Written {len(content)} bytes to {path}")
