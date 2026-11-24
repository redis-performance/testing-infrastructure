#!/bin/bash
# Connects this host to Twingate, once, for every runner on it: the runner users have no sudo, so a job
# can't install or start the client itself (Twingate/github-action needs sudo), and the client is one per
# host, so jobs must not reconfigure it under each other. Reads the service key (the JSON of a Twingate
# service account key) from the SSM SecureString __SSM_PREFIX__/twingate-service-key, installs the
# client, sets it up headless and enables its service, then deletes the parameter. The key never reaches
# a command line. Safe to re-run with a fresh parameter (key rotation). Run as root, through Session Manager.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
param="__SSM_PREFIX__/twingate-service-key"
key=$(mktemp); chmod 0600 "$key"
trap 'rm -f "$key"' EXIT
if ! aws ssm get-parameter --region __REGION__ --name "$param" --with-decryption \
     --query Parameter.Value --output text > "$key" 2>/dev/null; then
  echo "no $param: Twingate not set up (put the key there and run this again)"
  exit 0
fi
jq -e . "$key" >/dev/null || { echo "$param is not JSON" >&2; exit 1; }

if ! command -v twingate >/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y -q --no-install-recommends gnupg
  curl -fsSL --retry 5 https://packages.twingate.com/apt/gpg.key |
    gpg --batch --yes --no-tty --dearmor -o /usr/share/keyrings/twingate-client-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/twingate-client-keyring.gpg] https://packages.twingate.com/apt/ * *" \
    > /etc/apt/sources.list.d/twingate.list
  apt-get update -q -o Dir::Etc::sourcelist="sources.list.d/twingate.list" -o Dir::Etc::sourceparts="-" \
    -o APT::Get::List-Cleanup="0"
  apt-get install -y -q twingate
fi

if pgrep -f 'Runner.Worker' >/dev/null && [ "$(twingate status 2>/dev/null || true)" = online ]; then
  echo "a job is running on a connected client; rotate the key when the runners are idle" >&2
  exit 1
fi
twingate stop >/dev/null 2>&1 || true
twingate setup --headless - < "$key"
systemctl enable twingate >/dev/null 2>&1 || true
for _ in $(seq 1 12); do
  twingate start >/dev/null 2>&1 || true
  sleep 5
  [ "$(twingate status 2>/dev/null || true)" = online ] && break
done
status=$(twingate status 2>/dev/null || true)
[ "$status" = online ] || { echo "Twingate is '$status', not online" >&2; exit 1; }
aws ssm delete-parameter --region __REGION__ --name "$param" >/dev/null
echo "twingate: online"
