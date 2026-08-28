# syncthing

Syncthing file sync (syncthing/syncthing 2.1.3) as a single StatefulSet: web
UI :8384, sync :22000 TCP+UDP, discovery :21027/UDP, all routed through
Gateway API HTTPRoute/TCPRoute/UDPRoute in base. The nishir overlay mounts 19
Longhorn PVCs (Archives, Downloads, Movies, Music, Sukebe/*, Hermes/*, ...)
and fronts the web UI with a cert-manager certificate served over HTTPS, with
a BackendTLSPolicy for gateway-to-backend TLS.

## Layout

- `base/` — StatefulSet, Service (sessionAffinity ClientIP), config PVC,
  VPA, netpol (kube-system only), HTTPRoute/TCPRoute/UDPRoute.
- `components/tls/` — patches mounting the `syncthing-tls` secret and
  switching probes to HTTPS.
- `overlays/nishir/` — namespace, TLS component, cert.yaml (ClusterIssuer
  nishir), BackendTLSPolicy, route/PVC patches, 19 data PVC mounts.
