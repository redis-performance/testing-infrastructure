#!/bin/bash
# Select which storage condition this runner serves, then rebuild and restart
# the coordinator so benchmark data lands on that mount.
#
#   benchmark-storage-condition nvme     serve the local-NVMe condition
#   benchmark-storage-condition ebs      serve the dedicated-EBS condition
#   benchmark-storage-condition status   show what is active
#
# Two things change together, and both matter:
#
#   HOME             the coordinator does `tempfile.mkdtemp(dir=Path.home())`
#                    and bind-mounts that dir as the redis `--dir`. Relocating
#                    HOME is what actually moves benchmark data onto the mount.
#                    There is no --datadir flag upstream (see README).
#
#   --platform-name  results are namespaced by platform in the timeseries DB.
#                    If both conditions published under one name their series
#                    would interleave and the EBS/NVMe baselines would silently
#                    merge -- exactly what testing-infrastructure#162 says must
#                    not happen. Each condition gets its own suffixed platform.

set -euo pipefail

ENV_FILE="/etc/benchmark-runner.env"
ACTIVE_FILE="/etc/benchmark-storage-active.json"
SUPERVISOR_CONF="/etc/supervisor/conf.d/redis-benchmarks-spec-sc-coordinator.conf"
COORDINATOR_BIN="/usr/local/bin/redis-benchmarks-spec-sc-coordinator"

usage() { echo "usage: $(basename "$0") {nvme|ebs|status}" >&2; exit 2; }
die() { echo "ERROR: $*" >&2; exit 1; }

[ $# -eq 1 ] || usage
ACTION="$1"

if [ "$ACTION" = "status" ]; then
    if [ -f "$ACTIVE_FILE" ]; then cat "$ACTIVE_FILE"; else echo '{"active": null}'; fi
    exit 0
fi

case "$ACTION" in
    nvme) MOUNT="/mnt/nvme"; SUFFIX="-nvme" ;;
    ebs)  MOUNT="/mnt/ebs";  SUFFIX="-ebs"  ;;
    *) usage ;;
esac

[ "$(id -u)" -eq 0 ] || die "must run as root"
[ -f "$ENV_FILE" ] || die "$ENV_FILE not found"
# shellcheck disable=SC1090
. "$ENV_FILE"

# Refuse rather than let benchmark data silently land on the root volume.
mountpoint -q "$MOUNT" || die "$MOUNT is not a mountpoint. Run prepare_storage.sh first."

# A running coordinator mid-benchmark would leave a half-written result and an
# unacked stream message. Make the operator stop it deliberately.
if supervisorctl status redis-benchmarks-spec-sc-coordinator 2>/dev/null | grep -q RUNNING; then
    die "coordinator is RUNNING. Stop it first: sudo supervisorctl stop redis-benchmarks-spec-sc-coordinator"
fi

COORD_HOME="${MOUNT}/coordinator-home"
PLATFORM="${PLATFORM_NAME_BASE}${SUFFIX}"

# Supervisor runs the coordinator as root (no `user =` in the block below),
# matching the rest of the fleet: the benchmark containers need the docker
# socket, and RUNNER_USER is not in the docker group on these images. Setting
# `user =` here crash-loops the coordinator on docker.from_env() with
# PermissionError(13) against /var/run/docker.sock.
mkdir -p "$COORD_HOME"
chown "${RUNNER_USER}:${RUNNER_USER}" "$COORD_HOME"

EXPLICIT_FLAG=""
[ "${EXPLICIT_ONLY:-1}" = "1" ] && EXPLICIT_FLAG="--explicit-only"

cat > "$SUPERVISOR_CONF" <<CONF
[program:redis-benchmarks-spec-sc-coordinator]
command = ${COORDINATOR_BIN} --platform-name ${PLATFORM} --arch ${ARCH} --event_stream_host ${EVENT_STREAM_HOST} --event_stream_port ${EVENT_STREAM_PORT} --event_stream_user ${EVENT_STREAM_USER} --event_stream_pass ${EVENT_STREAM_PASS} --datasink_push_results_redistimeseries --datasink_redistimeseries_host ${DATASINK_RTS_HOST} --datasink_redistimeseries_port ${DATASINK_RTS_PORT} --datasink_redistimeseries_pass ${DATASINK_RTS_PASS} --tests-regexp '${TESTS_REGEXP}' ${EXPLICIT_FLAG} --logname /var/opt/redis-benchmarks-spec-sc-coordinator-1.log
directory = ${COORD_HOME}
environment = HOME="${COORD_HOME}",TMPDIR="${COORD_HOME}"
startsecs = 0
autostart = ${AUTOSTART:-false}
autorestart = true
startretries = 1
CONF

cat > "$ACTIVE_FILE" <<JSON
{
  "active_condition": "${ACTION}",
  "mount": "${MOUNT}",
  "platform_name": "${PLATFORM}",
  "coordinator_home": "${COORD_HOME}",
  "tests_regexp": "${TESTS_REGEXP}",
  "explicit_only": ${EXPLICIT_ONLY:-1},
  "selected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

supervisorctl reread >/dev/null
supervisorctl update >/dev/null

echo "storage condition set to '${ACTION}'"
cat "$ACTIVE_FILE"
echo
if [ "${AUTOSTART:-false}" = "true" ]; then
    supervisorctl start redis-benchmarks-spec-sc-coordinator || true
    echo "coordinator started (autostart=true)."
else
    echo "coordinator is configured but NOT started (autostart=false)."
    echo "start it when you are ready to accept work:"
    echo "  sudo supervisorctl start redis-benchmarks-spec-sc-coordinator"
fi
echo
echo "target it with:"
echo "  redis-benchmarks-spec-cli --target-platform ${PLATFORM} --arch ${ARCH} ..."
