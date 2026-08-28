# inference

Envoy AI Gateway serving OpenAI-schema inference over the free-tier pool:
nous → openrouter → qwen-27b → deepseek-flash, priority failover on
429/5xx. The pool is selected by the `x-model-pool: free` header.

## Layout

- `base/` — GatewayClass, EnvoyProxy (stable data-plane Service name),
  Gateway (HTTPS :443), ClientTrafficPolicy (mTLS), Backends,
  AIServiceBackends, BackendSecurityPolicies, AIGatewayRoute.
- `components/tls/` — Certificate from the nishir ClusterIssuer,
  ClientTrafficPolicy requiring client certs, Gateway listener patch to
  HTTPS + mTLS.
- `overlays/nishir-tailnet/` — SOPS API-key Secrets (below); the data-plane
  Service is published by the Tailscale operator (`loadBalancerClass`,
  L4) instead of an Ingress, so client certs reach the listener intact.

## TLS

- Listener: HTTPS, terminate, cert from ClusterIssuer `nishir`
  (Secret `inference-tls`), **client certs required** — signed by the
  same CA; the trust-manager Bundle `nishir-ca-certificates.crt`
  (ConfigMap, key `ca.crt`) is the trust anchor.
- Local floors: plain HTTP `Backend` FQDNs. TODO when llama-cpp serves
  TLS: switch to `caCertificateRefs: [nishir-ca-certificates.crt]` for
  real mTLS to the floors.
- Remote providers: system-CA-validated TLS (api.nousresearch.com,
  openrouter.ai).
- Outside the cluster, tailscale leads (encrypted by construction).

## API keys

One folder per secret under `overlays/nishir-tailnet/`, wired by the
overlay's `secretGenerator` with `envs:` — one Secret per provider with
data key `apiKey` (the literal key the BackendSecurityPolicy reads):

- `inference-nous/.enc.env` → Secret `inference-nous`
- `inference-openrouter/.enc.env` → Secret `inference-openrouter`

Re-encrypt with the flake's sops config after editing values; recipients
are governed by the catch-all creation rule (workstations + nishir key).
Never commit decrypted values.

## Client certificate

Issue one per consumer from the nishir CA (serverAndClient auth):

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-mtls-client
  namespace: shikanime
spec:
  commonName: example
  issuerRef: { name: nishir, kind: ClusterIssuer }
  secretName: example-mtls-client
  usages: [digital signature, key encipherment, client auth]
EOF
```

Then `curl --cacert ca.crt --cert tls.crt --key tls.key`
`https://inference.taila659a.ts.net/v1/chat/completions ...` (the
in-cluster Service names are SANs too).

## Usage

```bash
curl https://inference.taila659a.ts.net/v1/chat/completions \
  --cacert <nishir-ca.crt> --cert <client.crt> --key <client.key> \
  -H 'Content-Type: application/json' -H 'x-model-pool: free' \
  -d '{"model":"qwen/qwen3-8b","messages":[{"role":"user","content":"ping"}]}'
```
