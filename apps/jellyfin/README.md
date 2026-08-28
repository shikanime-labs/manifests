# jellyfin

Jellyfin media server (jellyfin/jellyfin 10.11.11) exposing HTTP :8096 and UDP
:7359 discovery; the Service (ClientIP affinity) fronts :8096. Config lives on
the 32Gi `jellyfin-config` PVC, and the NetworkPolicy admits the servarr family
(bazarr, lidarr, radarr, seerr, sonarr, whisparr) on http.

## Layout

- `base/` — StatefulSet, Service, PVC, NetworkPolicy, VPA.
- `components/gpu/` — /dev/dri hostPath, privileged, render/media groups.
- `components/ldap/` — LDAP-Auth plugin config from the `jellyfin-ldap` Secret.
- `components/tls/` — PKCS12 keystore from the nishir CA, HTTPS :8920, probes
  switch to https.
- `overlays/nishir/` — TLS/ldap/gpu components, media PVCs (movies, music,
  shows, sukebe-*, timeline), Intel iGPU (pci-0300_8086) + 2.5g node affinity,
  SOPS secrets.
- `overlays/nishir-tailnet/` — Tailscale Ingress (defaultBackend https), netpol
  for tailscale-system/vmagent, published URL jellyfin.taila659a.ts.net.
