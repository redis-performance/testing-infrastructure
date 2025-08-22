#!/usr/bin/env bash
# Simple checker for required environment variables used by env.sh/terraform external data.
# Fails with exit code 1 if any are missing.
set -euo pipefail

REQUIRED_VARS=(
  EVENT_STREAM_HOST
  EVENT_STREAM_PORT
  EVENT_STREAM_USER
  EVENT_STREAM_PASS
  DATASINK_RTS_HOST
  DATASINK_RTS_PORT
  DATASINK_RTS_PASS
)

# Control whether to show secrets. Set SHOW_SECRETS=1 to print unmasked values.
SHOW_SECRETS="${SHOW_SECRETS:-0}"

# Control whether to run Redis connectivity checks. Set SKIP_REDIS_CHECKS=1 to skip.
SKIP_REDIS_CHECKS="${SKIP_REDIS_CHECKS:-0}"

mask_value() {
  local val="$1"
  if [[ "$SHOW_SECRETS" == "1" ]]; then
    echo "$val"
  else
    local len=${#val}
    if (( len <= 4 )); then
      echo "****"
    else
      echo "${val:0:2}***${val: -2}"
    fi
  fi
}


# Helper to detect if a var name is secret-like
is_secret() {
  case "$1" in
    *PASS) return 0 ;;
    *)     return 1 ;;
  esac
}


# Print values (masking secrets by default)
for v in "${REQUIRED_VARS[@]}"; do
  val="${!v:-}"
  if is_secret "$v"; then
    echo "$v=$(mask_value "$val")"
  else
    echo "$v=$val"
  fi
done

# Generic Redis connectivity check function
check_redis_connection() {
  local name="$1"
  local host="$2"
  local port="$3"
  local pass="$4"
  local user="$5"  # Optional, empty for default user

  if ! command -v redis-cli >/dev/null 2>&1; then
    echo "  ❌ redis-cli not found - skipping $name connectivity check"
    return 1
  fi

  local masked_pass
  if [[ "$SHOW_SECRETS" == "1" ]]; then
    masked_pass="$pass"
  else
    masked_pass=$(mask_value "$pass")
  fi

  local conn_str="redis://$host:$port"
  if [[ -n "$user" ]]; then
    conn_str="redis://$user@$host:$port"
  fi

  echo "  🔍 Testing $name connection to $conn_str (pass: $masked_pass)"

  local cmd_args=(-h "$host" -p "$port")
  if [[ -n "$pass" ]]; then
    cmd_args+=(-a "$pass")
  fi
  if [[ -n "$user" ]]; then
    cmd_args+=(--user "$user")
  fi
  cmd_args+=(-t 5 ping)

  if redis-cli "${cmd_args[@]}" >/dev/null 2>&1; then
    echo "  ✅ $name connection successful"
    return 0
  else
    echo "  ❌ $name connection failed"
    return 1
  fi
}

# Run Redis connectivity checks for both groups
run_connectivity_checks() {
  if [[ "$SKIP_REDIS_CHECKS" == "1" ]]; then
    echo "Skipping Redis connectivity checks (SKIP_REDIS_CHECKS=1)"
    return 0
  fi

  echo ""
  echo "Testing Redis connectivity..."

  local event_stream_ok=0
  local datasink_ok=0

  # Group 1: Event Stream Redis
  echo ""
  echo "Group 1: Event Stream Redis"
  if check_redis_connection "Event Stream" \
    "${EVENT_STREAM_HOST:-}" \
    "${EVENT_STREAM_PORT:-}" \
    "${EVENT_STREAM_PASS:-}" \
    "${EVENT_STREAM_USER:-}"; then
    event_stream_ok=1
  fi

  # Group 2: Datasink RTS Redis
  echo ""
  echo "Group 2: Datasink RTS Redis"
  if check_redis_connection "Datasink RTS" \
    "${DATASINK_RTS_HOST:-}" \
    "${DATASINK_RTS_PORT:-}" \
    "${DATASINK_RTS_PASS:-}" \
    ""; then  # No user for RTS, use default
    datasink_ok=1
  fi

  echo ""
  if [[ $event_stream_ok -eq 1 && $datasink_ok -eq 1 ]]; then
    echo "✅ All Redis connectivity checks passed"
    return 0
  else
    echo "❌ Some Redis connectivity checks failed"
    if [[ $event_stream_ok -eq 0 ]]; then
      echo "  - Event Stream Redis connection failed"
    fi
    if [[ $datasink_ok -eq 0 ]]; then
      echo "  - Datasink RTS Redis connection failed"
    fi
    return 1
  fi
}

missing=()
for v in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    missing+=("$v")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "Missing required environment variables:" >&2
  for v in "${missing[@]}"; do
    echo "  - $v" >&2
  done
  exit 1
fi

echo "All required environment variables are set."

# Run Redis connectivity checks
run_connectivity_checks
