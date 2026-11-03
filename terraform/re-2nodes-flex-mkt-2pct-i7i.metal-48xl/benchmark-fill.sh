#!/bin/bash
set -euo pipefail

# Fill benchmark for Marketing Flex 2-node test
# Usage: ./benchmark-fill.sh <ENDPOINT> <VALUE_SIZE> <HALF>
#   ENDPOINT: cluster endpoint (e.g. 172.31.x.x:12000)
#   VALUE_SIZE: one of 4096, 8192, 16384, 32768, 65536
#   HALF: 0 = first half of keys, 1 = second half (for splitting across 2 clients)

ENDPOINT=${1:?"Usage: $0 <ENDPOINT> <VALUE_SIZE> <HALF>"}
VALUE_SIZE=${2:?"Usage: $0 <ENDPOINT> <VALUE_SIZE> <HALF>"}
HALF=${3:?"Usage: $0 <ENDPOINT> <VALUE_SIZE> <HALF>"}

HOST=$(echo "$ENDPOINT" | cut -d: -f1)
PORT=$(echo "$ENDPOINT" | cut -d: -f2)

# 5TB fill per value size
TOTAL_BYTES=$((5 * 1024 * 1024 * 1024 * 1024))
TOTAL_KEYS=$((TOTAL_BYTES / VALUE_SIZE))
HALF_KEYS=$((TOTAL_KEYS / 2))

if [ "$HALF" -eq 0 ]; then
    KEY_MIN=1
    KEY_MAX=$HALF_KEYS
else
    KEY_MIN=$((HALF_KEYS + 1))
    KEY_MAX=$TOTAL_KEYS
fi

RESULTS_DIR="results-mkt-fill-${VALUE_SIZE}b"
mkdir -p "$RESULTS_DIR"

echo "=== Fill: value_size=${VALUE_SIZE}, keys=${KEY_MIN}-${KEY_MAX} (half=$HALF) ==="
echo "Total keys for this value size: $TOTAL_KEYS, this client fills: $HALF_KEYS"

memtier_benchmark \
    -s "$HOST" \
    -p "$PORT" \
    --ratio=1:0 \
    --key-pattern=P:P \
    --key-minimum="$KEY_MIN" \
    --key-maximum="$KEY_MAX" \
    --data-size="$VALUE_SIZE" \
    -n allkeys \
    --pipeline=10 \
    --threads=16 \
    --clients=20 \
    --cluster-mode \
    --tls \
    --tls-skip-verify \
    --hide-histogram \
    --json-out-file="$RESULTS_DIR/fill-half${HALF}.json" \
    2>&1 | tee "$RESULTS_DIR/fill-half${HALF}.log"

echo "=== Fill complete: value_size=${VALUE_SIZE}, half=${HALF} ==="
