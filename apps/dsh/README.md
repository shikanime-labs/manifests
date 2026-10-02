# dsh

DeepSeek Harness (`dsh`) agent pod: a single-replica StatefulSet `dsh`
running `dsh --profile acp` from the
`ghcr.io/shikanime-labs/machines/dsh` image (built by
`shikanime-labs/machines` `pkgs/dsh-oci-image`) in `shikanime`.

Nothing listens: the web profile is loopback-only by upstream design
(`--host 0.0.0.0` is rejected as an RCE hazard), so there is no
Service, route, or exposure. The ACP profile serves automation clients
over stdio and idles until a client connects — with `stdin: true` it
is the keep-alive process. Attach interactively:

- `kubectl exec -it dsh-0 -- dsh plugin --profile acp <pnpm args>` —
  manage the profile's plugins.
- `kubectl port-forward pod/dsh-0 18443:18443` then
  `kubectl exec -it dsh-0 -- dsh --profile web --port 18443
  --no-open` — use the Web UI through the forwarded loopback; open
  the printed `?token=` URL locally.

## Layout

- `base/` — StatefulSet, VPA (`InPlace`, restarts kill agent
  sessions), deny-all netpol (no intra-app flow exists). 512Mi
  Longhorn `home` volumeClaimTemplate at `/home/dsh`: profile state,
  sessions, and plugin installs persist across restarts; the image
  user is 65532 and `fsGroup` matches. Image pinned to the
  multi-arch index digest.
- amd64 is excluded: dsh's native loader fails its getter scan
  against Nix-built Node (`Unsupported/no-getter`) and the nodeabi
  fallback ships no linux-x64 prebuilds, so the pod pins
  `kubernetes.io/arch: arm64` (verified live on `minish`).
- `overlays/nishir/` — namespace only.
- `overlays/nishir-tailnet/` — the five-key label set; the Flux
  `apps-dsh` Kustomization targets this overlay.

The DeepSeek API key is supplied at attach time (the exec'ing shell's
environment); no key material is stored in the cluster.
