# cert-manager CA rotation recovery

## Problem

The `nishir` ClusterIssuer is backed by a self-signed CA Certificate
(`nishir-ca`, `CN=cluster.local`, 90-day duration, in
`configs/cert-manager/overlays/nishir/cert.yaml`). When cert-manager renews
that CA (it did at 2026-09-05T00:27:36Z on `nishir`), **workload certificates
already issued by the old CA are NOT re-issued** — cert-manager only renews a
leaf when the leaf itself nears expiry. Every pod that validates an mTLS peer
against the new CA (propagated fleet-wide by the trust-manager Bundle
`nishir-ca-certificates.crt` within minutes) fails with
`certificate signed by unknown authority` while the peer still serves the
old-CA cert.

Observed blast radius on 2026-09-05:

- authelia → lldap `ldaps://` startup check: FATAL, crash-loop
- Envoy Gateway → authelia backend (BackendTLSPolicy): 503 upstream
- EG OIDC discovery fetch: 503 → SecurityPolicy `Accepted=False/Invalid` →
  auth filters dropped → clients got raw `Jwt is missing` 401s

## One-off recovery (what was done)

Delete every Certificate secret issued by the rotated CA; cert-manager
re-issues from the new CA immediately; kubelet syncs the mounted secrets;
crash-looping pods recover on their next restart, others need a pod delete.

```sh
# list victims (issuer name == the rotated ClusterIssuer)
kubectl -n shikanime get certificates -o json | jq -r '
  .items[] | select(.spec.issuerRef.name=="nishir")
  | "\(.metadata.name) \(.spec.secretName)"'

# nuke + let cert-manager re-issue (use --wait=false; it is fast)
kubectl -n shikanime delete secret authelia-tls lldap-tls copyparty-tls ... --wait=false

# verify a leaf now chains to the bundle
kubectl -n shikanime get secret lldap-tls \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/leaf.crt
kubectl -n shikanime get cm nishir-ca-certificates.crt \
  -o jsonpath='{.data.ca\.crt}' > /tmp/bundle.pem
# -> OK
openssl verify -CAfile /tmp/bundle.pem /tmp/leaf.crt

# restart stateful pods that cache certs at boot and are not crash-looping
kubectl -n shikanime delete pod lldap-0 authelia-0
```

Do not restart the whole fleet blindly: crash-looping pods self-heal; healthy
pods keep serving old-CA certs until restarted, and that is fine unless two
old-CA peers need to talk to each other (both still trust the old CA only if
it is still in the bundle — it is not, so mTLS pairs both on old certs keep
working; old↔new pairs break; restart the smaller side first).

## Prevention options (pick one)

1. **Long CA duration (recommended, laziest).** Set
   `spec.duration: 87600h` (10y) + `spec.renewBefore: 720h` on the
   `nishir-ca` Certificate. A CA that practically never rotates cannot break
   the fleet. Rotation of a self-signed root buys nothing here — the trust
   bundle IS the CA.
2. **Fleet re-issue on CA change.** Keep 90d CA and automate the recovery:
   a Flux `ImageAutomation`-style cron (or Kyverno rule on the
   `nishir-ca` secret) that annotates all
   `cert-manager.io` Certificates with `cert-manager.io/issue-temporary-certificate`
   … in practice: `kubectl get certificates -o name | xargs kubectl annotate
   certificate cert-manager.io/certificate-duration=...` is NOT a trigger;
   the real trigger is deleting the secrets (as above) or `cmctl renew`.
   Script it, run it from the same automation that rotates the CA.
3. **JWKS-free service mesh mTLS** (Linkerd/Istio) issues short-lived
   identities and re-distributes trust automatically — the heavyweight fix;
   only worth it if mTLS sprawl keeps growing.

Option 1 is the ponytail answer: one YAML field, no moving parts.

## Related

- `longhorn-rwx-xfs-recovery.md` — the archives-data outage that rode along
- trust-manager Bundle `nishir-ca-certificates.crt`
  (`configs/cert-manager/overlays/nishir/bundle.yaml`) — how the new CA
  reached every node before the leaves did
