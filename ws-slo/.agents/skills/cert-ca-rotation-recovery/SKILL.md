---
name: cert-ca-rotation-recovery
description: Use when mTLS peers fail after a cert-manager CA renewal.
version: 0.1.0
author: Shikanime Deva, Hermes Agent
license: Apache-2.0
platforms: [linux, macos]
metadata:
  hermes:
    tags: [cert-manager, ca-rotation, mtls, envoy, recovery, nishir]
    related_skills: [envoy-gateway-oidc]
---

# cert-manager CA Rotation Recovery

When the `nishir` self-signed CA Certificate renews (`nishir-ca`,
`CN=cluster.local`, `configs/cert-manager/overlays/nishir/cert.yaml`),
already-issued workload certificates are NOT re-issued — cert-manager renews a
leaf only near its own expiry. Every pod validating an mTLS peer against the
new CA (propagated fleet-wide within minutes by the trust-manager Bundle
`nishir-ca-certificates.crt`) fails `certificate signed by unknown authority`
while the peer still serves the old-CA cert.

Observed blast radius (2026-09-05): authelia→lldap `ldaps://` crash-loop;
Envoy Gateway→authelia 503; EG OIDC discovery 503 → SecurityPolicy
`Accepted=False/Invalid` → auth filters dropped → raw `Jwt is missing` 401s.

## Procedure

1. List victims: certificates whose `spec.issuerRef.name` equals the rotated
   ClusterIssuer (`kubectl -n <ns> get certificates -o json` + jq select).
2. Delete their secrets (`--wait=false`; re-issue is fast). cert-manager
   re-issues from the new CA immediately; kubelet syncs mounted secrets.
3. Verify a leaf chains to the bundle: `openssl verify -CAfile <bundle.pem>
   <leaf.crt>` (leaf from the secret's `tls.crt`, CA from the ConfigMap).
4. Restart stateful pods that cache certs at boot and are not crash-looping
   (crash-looping pods self-heal on next restart).

Restart the smaller side of an old↔new mTLS pair first; old↔old pairs keep
working, old↔new pairs break. Do not restart the whole fleet blindly.

## Prevention (pick one)

1. **Long CA duration (recommended).** `spec.duration: 87600h` +
   `spec.renewBefore: 720h` on the CA Certificate. A CA that never rotates
   cannot break the fleet; the trust bundle IS the CA.
2. Fleet re-issue automation (Kyverno rule / cron) — the real trigger is
   deleting the secrets or `cmctl renew`; annotating certificates is NOT one.
3. Service-mesh mTLS (Linkerd/Istio) — heavyweight, only for growing mTLS
   sprawl.

## Verification

`openssl verify` passes for every re-issued leaf; previously crash-looping
pods `Running`; the OIDC SecurityPolicy back to `Accepted=True`.
