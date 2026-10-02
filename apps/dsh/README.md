# dsh

DeepSeek Harness (`dsh`) agent pod: a single-replica StatefulSet `dsh`
running the `ghcr.io/shikanime-labs/machines/dsh` image (built by
`shikanime-labs/machines` `pkgs/dsh-oci-image`) in `shikanime`,
exposed at `chat.i.shikanime.studio`.

The web profile is loopback-only by upstream design (`--host 0.0.0.0`
is rejected at argument parse as an RCE hazard); dsh binds
`127.0.0.1:18080` and an `alpine/socat` sidecar bridges
`podIP:8080` to it, so the loopback invariant holds while a Service
can route. The web process is the keep-alive (`stdin: true` is
retained); attach for ACP with `kubectl exec -it dsh-0 -- dsh
--profile acp`. Envoy terminates TLS for `chat.i.shikanime.studio`
and forwards plaintext to the bridge; the per-boot URL token still
authenticates the UI, and `--trusted-host` admits the public
hostname to the browser-trust fence.

## Layout

- `base/` — Service (80→bridge 8080), Gateway (http redirect +
  https Terminate → cert `studio-shikanime-i-dsh`), HTTPRoutes,
  centralized-recipe Certificate (`chat.i.shikanime.studio`,
  issuer `studio-shikanime`), netpol, VPA (`InPlace`, restarts
  kill agent sessions), and the StatefulSet: dsh web on loopback
  - socat bridge sidecar, both PSS-restricted securityContexts,
  tcpSocket probes, 512Mi Longhorn `home` volumeClaimTemplate at
  `/home/dsh` (profile state, sessions, plugin installs persist
  across restarts; image user 65532, `fsGroup` matches). Image
  pinned to the multi-arch index digest.
- amd64 is excluded: dsh's native loader fails its getter scan
  against Nix-built Node (`Unsupported/no-getter`) and the nodeabi
  fallback ships no linux-x64 prebuilds, so the pod pins
  `kubernetes.io/arch: arm64` (verified live on `minish`).
- `overlays/nishir/` — namespace only.
- `overlays/nishir-tailnet/` — the five-key label set, the BYOD
  dataplane (EnvoyProxy `dsh`, tailscale LB `dsh-proxy`,
  `tag:web`; GatewayClass `dsh`), the route hostname/parent
  patches, and the netpol patch admitting `envoy-gateway-system`
  envoy pods. external-dns publishes `chat.i.shikanime.studio` →
  the tailnet CGNAT A (off-tailnet clients time out by design);
  the Flux `apps-dsh` Kustomization targets this overlay.

The DeepSeek API key is supplied at attach time (the exec'ing
shell's environment) or entered in the Web UI; no key material is
stored in the cluster.
