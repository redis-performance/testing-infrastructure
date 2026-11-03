#!/bin/bash
set -euo pipefail

# Workload benchmark for Marketing Flex 2-node test
# Usage: ./benchmark-workload.sh <ENDPOINT> <VALUE_SIZE> <WORKLOAD> <RATE> <HALF> [TEST_TIME]
#   ENDPOINT: cluster endpoint (e.g. 172.31.x.x:12000)
#   VALUE_SIZE: one of 4096, 8192, 16384, 32768, 65536
#   WORKLOAD: "read" (0:1), "mixed" (1:4), "write" (1:0)
#   RATE: 0 = max throughput, >0 = rate limit per thread
#   HALF: 0 or 1 (determines key range for this client)
#   TEST_TIME: duration in seconds (default: 120)

ENDPOINT=${1:?"Usage: $0 <ENDPOINT> <VALUE_SIZE> <WORKLOAD> <RATE> <HALF> [TEST_TIME]"}
VALUE_SIZE=${2:?"Usage: $0 <ENDPOINT> <VALUE_SIZE> <WORKLOAD> <RATE> <HALF> [TEST_TIME]"}
WORKLOAD=${3:?"Usage: $0 <ENDPOINT> <VALUE_SIZE> <WORKLOAD> <RATE> <HALF> [TEST_TIME]"}
RATE=${4:?"Usage: $0 <ENDPOINT> <VALUE_SIZE> <WORKLOAD> <RATE> <HALF> [TEST_TIME]"}
HALF=${5:?"Usage: $0 <ENDPOINT> <VALUE_SIZE> <WORKLOAD> <RATE> <HALF> [TEST_TIME]"}
TEST_TIME=${6:-120}

HOST=$(echo "$ENDPOINT" | cut -d: -f1)
PORT=$(echo "$ENDPOINT" | cut -d: -f2)

# Key range (same as fill)
TOTAL_BYTES=$((5 * 1024 * 1024 * 1024 * 1024))
TOTAL_KEYS=$((TOTAL_BYTES / VALUE_SIZE))

case "$WORKLOAD" in
    read)   RATIO="0:1" ;;
    mixed)  RATIO="1:4" ;;
    write)  RATIO="1:0" ;;
    *)      echo "Unknown workload: $WORKLOAD (use read/mixed/write)"; exit 1 ;;
esac

RATE_LABEL="max"
RATE_ARGS=""
if [ "$RATE" -gt 0 ]; then
    RATE_LABEL="${RATE}rps"
    RATE_ARGS="--rate-limiting=$RATE"
fi

RESULTS_DIR="results-mkt-${VALUE_SIZE}b-${WORKLOAD}-${RATE_LABEL}"
mkdir -p "$RESULTS_DIR"

echo "=== Workload: size=${VALUE_SIZE}, workload=${WORKLOAD}, ratio=${RATIO}, rate=${RATE_LABEL}, half=${HALF}, time=${TEST_TIME}s ==="

memtier_benchmark \
    -s "$HOST" \
    -p "$PORT" \
    --ratio="$RATIO" \
    --key-pattern=R:R \
    --key-minimum=1 \
    --key-maximum="$TOTAL_KEYS" \
    --data-size="$VALUE_SIZE" \
    --test-time="$TEST_TIME" \
    --pipeline=1 \
    --threads=16 \
    --clients=20 \
    --cluster-mode \
    --tls \
    --tls-skip-verify \
    --print-percentiles=50,90,95,99,99.9,99.99 \
    --json-out-file="$RESULTS_DIR/workload-half${HALF}.json" \
    $RATE_ARGS \
    2>&1 | tee "$RESULTS_DIR/workload-half${HALF}.log"

echo "=== Workload complete: ${VALUE_SIZE}b ${WORKLOAD} ${RATE_LABEL} half=${HALF} ==="
