# SOPS-encrypted API keys for the free-tier backends

## Create with: sops --age <key> nous-api-key.enc.env

## Content (one var per file)

## NOUS_API_KEY=sk-... -> nous-api-key.enc.env

## OPENROUTER_API_KEY=sk-or-... -> openrouter-api-key.enc.env

## The secretGenerator in base/kustomization.yaml mounts these as a single

## Secret (envs) keyed by filename stem: nous-api-key, openrouter-api-key

## Do NOT commit the decrypted values
