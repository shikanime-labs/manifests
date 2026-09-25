---
name: sops-secrets-authoring
description: Use when adding, editing, or removing SOPS-encrypted secrets (*.enc.*) in this repo.
version: 0.1.0
author: Shikanime Deva, Hermes Agent
license: Apache-2.0
platforms: [linux, macos]
metadata:
  hermes:
    tags: [sops, age, secrets, encryption, nishir]
    related_skills: [overlay-authoring, flux-ks-recovery]
---

# SOPS Secrets Authoring

AGENTS.md §Secrets owns the contract: field-level encryption via per-app
`encrypted_regex` rules in `flake.nix`, `*.enc.*` naming, Flux transparent
decryption. This skill owns the edit mechanics — where silent data loss and
non-encrypting failures live.

## Procedure (decrypt-edit-encrypt)

1. **Decrypt to a scratch path:** `sops -d <enc> > /tmp/plain.yml`. Never
   edit through pipes into the target.
2. **Store format is file-extension-driven.** `.enc.env` files are
   **dotenv**, not YAML (the `sops_age__list_N__map_enc` keys are the tell):

   ```bash
   sops --input-type dotenv --output-type dotenv -d <file>.enc.env
   # encrypt likewise; YAML codec on dotenv fails with
   # "cannot unmarshal !!str ... into map[string]interface{}"
   ```

3. **Edit with a real YAML library**, never `sed` append (indentation
   mistakes stay masked behind later errors for rounds). Validate before
   encrypting: `yaml.safe_load` parses AND the semantic delta vs the
   decrypted `main` version is exactly the intended subtree.
4. **Encrypt capturing STDOUT programmatically.** Never `>` redirect into
   the target — a failed sops run truncates it to zero bytes (`git checkout
   -- <file>` restores). Verify the file exists and roundtrip-decrypts after
   every encrypt; zero bytes = failed, not succeeded.
5. **Roundtrip against ground truth:** `sops -d <new>` must equal the edited
   plaintext semantically (byte-compare fails on serialization noise; the
   oracle is what sops stored, not your local copy).

## Recipients and rules — the two silent-killers

- **Extract ALL recipients from the target file's own `sops.age` metadata**
  and re-encrypt against the FULL set:

  ```bash
  awk '/- recipient:/{print $NF}' <enc-file>
  ```

  Taking only the first silently drops every other key — on nishir that
  killed cluster Flux decryption for the whole repo (`no identity matched
  any of the recipients`). A single recipient is normal only when the
  original had one; always count first. Cluster-decrypting files typically
  carry workstation + one key per consuming cluster.
- **sops 3.13+ rejects bare `--age` flags** (`no matching creation rules
  found`). Pass a scratch rules file explicitly; `creation_rules.path_regex`
  matches the INPUT path being encrypted, so a `/tmp` plaintext never
  matches the repo's rule — use a throwaway rule `path_regex: ".*"` carrying
  the file's real `encrypted_regex` and full recipient set. Only the
  ciphertext installs.

  ```bash
  sops --config /tmp/rules.yaml --encrypt --input-type yaml \
    --output-type yaml <plain>   # stdout → target, never redirect
  ```

  `age:` list entries must be bare recipient strings; `{recipient: ...}`
  maps fail (`expected string in list`).

## Field-level contract specifics

- Check the per-app `encrypted_regex` in `flake.nix` BEFORE assuming which
  keys are ciphertext. A new `.enc.*` file needs its regex entry first, or
  nothing you intended encrypts.
- Round-trip on the file with its own recipients — do not introduce a
  recipient set change in an edit PR.
- **Deleting a key needs key-level consumer checks**, not just `env:` /
  `envFrom:` sweeps: cert-manager `passwordSecretRef` references,
  config-file-embedded secrets (the key interpolated inside a mounted
  config), and any CR field pointing at the generated Secret's key.
- Never commit decrypted output; never print a whole decrypted file (line
  ranges and grep counts only).
- **`nix fmt` corrupts `.enc.yaml`** — treefmt reformats it as ordinary YAML
  and breaks the sops MAC (`MAC mismatch` on decrypt). Scope `nix fmt` to
  changed dirs and keep encrypted files out; if hit, restore the staged
  pre-format copy and re-verify decrypt.
- `nix eval` / flake builds read the GIT tree — stage edited files before
  any eval assertion.
- Encrypting rewrites every value (fresh nonce/MAC): a one-block semantic
  change renders as a ~145-line diff. Expected; say so in the PR body.
- secretGenerator output hash: changed encrypted VALUES change the
  generated Secret name → pod template hash → automatic sts restart after
  merge. Check pod `startedAt` against merge time before ordering a manual
  rollout.

## Verification

`sops -d <file> | yaml parse` (or dotenv) succeeds with the intended delta;
recipients in the new metadata match the original set; `kustomize build` of
the consuming overlay renders; CI treefmt clean.
