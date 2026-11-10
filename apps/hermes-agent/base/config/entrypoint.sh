#!/usr/bin/env bash
set -eu

HERMES_HOME=/var/lib/hermes/.hermes
export HERMES_HOME
export HOME=/var/lib/hermes

mkdir -p "$HERMES_HOME"

# .env = non-secret base + the sops-rendered channel secret files.
install -m 0640 /etc/hermes-agent/env-base "$HERMES_HOME/.env"
for f in /run/secrets/channel-env/*; do
  cat "$f" >>"$HERMES_HOME/.env"
  printf '\n' >>"$HERMES_HOME/.env"
done

install -m 0640 /etc/hermes-agent/config.yaml "$HERMES_HOME/config.yaml"
install -m 0640 /etc/hermes-agent/SOUL.md "$HERMES_HOME/SOUL.md"
install -m 0640 /etc/hermes-agent/honcho.json "$HERMES_HOME/honcho.json"
install -m 0640 /etc/hermes-agent/kubeconfig "$HERMES_HOME/kubeconfig"
mkdir -p "$HERMES_HOME/cron"
install -m 0640 /etc/hermes-agent/cron/jobs.json "$HERMES_HOME/cron/jobs.json"

# Backend (dashboard 9119, api-server 8642, a2a 9900, webhook 8644) in
# the background; gateway in the foreground.
hermes dashboard --host 0.0.0.0 --port 9119 --no-open &
exec hermes gateway
