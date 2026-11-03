#!/bin/bash
set -euo pipefail

# Orchestrator: runs all fill + workload benchmarks for Marketing Flex test
# Usage: ./benchmark-all.sh <ENDPOINT> <HALF> [VALUE_SIZES...]
#   ENDPOINT: cluster endpoint (e.g. 172.31.x.x:12000)
#   HALF: 0 or 1 (which half of keys this client handles)
#   VALUE_SIZES: optional, space-separated list (default: 4096 8192 16384 32768 65536)
#
# Examples:
#   ./benchmark-all.sh 172.31.x.x:12000 0              # all sizes
#   ./benchmark-all.sh 172.31.x.x:12000 0 4096          # 4K only
#   ./benchmark-all.sh 172.31.x.x:12000 0 4096 8192     # 4K and 8K
#
# Client 0 flushes the DB before each value size through the REST API on node 1:
#   RS_USER / RS_PASS: cluster admin credentials (required on client 0)
#   BDB_UID: database uid (default 1)

ENDPOINT=${1:?"Usage: $0 <ENDPOINT> <HALF> [VALUE_SIZES...]"}
HALF=${2:?"Usage: $0 <ENDPOINT> <HALF> [VALUE_SIZES...]"}
shift 2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ $# -gt 0 ]; then
    VALUE_SIZES=("$@")
else
    VALUE_SIZES=(4096 8192 16384 32768 65536)
fi
WORKLOADS=(read mixed write)
TEST_TIME=600

log() {
    echo ""
    echo "###############################################################################"
    echo "# $(date '+%Y-%m-%d %H:%M:%S') - $*"
    echo "###############################################################################"
    echo ""
}

for VS in "${VALUE_SIZES[@]}"; do
    log "FILL: value_size=${VS}"

    # Flush DB before each value size (only client 0 does flush via REST API on node 1)
    if [ "$HALF" -eq 0 ]; then
        HOST=$(echo "$ENDPOINT" | cut -d: -f1)
        log "Flushing DB before fill (value_size=${VS})"
        curl -sk -u "${RS_USER:?set RS_USER}:${RS_PASS:?set RS_PASS}" -X PUT \
            "https://${HOST}:9443/v1/bdbs/${BDB_UID:-1}/actions/flush" 2>&1
        sleep 10
    else
        # Client 1 waits for client 0 to flush
        sleep 20
    fi

    "$SCRIPT_DIR/benchmark-fill.sh" "$ENDPOINT" "$VS" "$HALF"

    # Wait for both clients to finish fill before workloads
    log "Fill done for ${VS}b, sleeping 30s before workloads..."
    sleep 30

    for WL in "${WORKLOADS[@]}"; do
        # Phase 1: max throughput (discover ceiling)
        log "WORKLOAD: ${VS}b ${WL} max"
        "$SCRIPT_DIR/benchmark-workload.sh" "$ENDPOINT" "$VS" "$WL" 0 "$HALF" "$TEST_TIME"
        sleep 10

        # Extract max ops/sec from JSON to compute 80% and 50% targets
        MAX_JSON="results-mkt-${VS}b-${WL}-max/workload-half${HALF}.json"
        if [ -f "$MAX_JSON" ]; then
            # Extract total ops/sec from memtier JSON (Totals -> "Ops/sec")
            MAX_OPS=$(python3 -c "
import json, sys
with open('$MAX_JSON') as f:
    data = json.load(f)
# Sum SET + GET ops/sec from ALL STATS
totals = data.get('ALL STATS', {}).get('Totals', {})
ops = totals.get('Ops/sec', 0)
print(int(ops))
" 2>/dev/null || echo "0")

            if [ "$MAX_OPS" -gt 0 ]; then
                RATE_80=$((MAX_OPS * 80 / 100 / 16 / 20 / 2))  # per-connection rate (16 threads × 20 clients × 2 cluster nodes)
                RATE_50=$((MAX_OPS * 50 / 100 / 16 / 20 / 2))

                # Phase 2: 80% of max
                log "WORKLOAD: ${VS}b ${WL} 80pct (${RATE_80}/thread, total target=$((RATE_80 * 16)))"
                "$SCRIPT_DIR/benchmark-workload.sh" "$ENDPOINT" "$VS" "$WL" "$RATE_80" "$HALF" "$TEST_TIME"
                sleep 10

                # Phase 3: 50% of max
                log "WORKLOAD: ${VS}b ${WL} 50pct (${RATE_50}/thread, total target=$((RATE_50 * 16)))"
                "$SCRIPT_DIR/benchmark-workload.sh" "$ENDPOINT" "$VS" "$WL" "$RATE_50" "$HALF" "$TEST_TIME"
                sleep 10
            else
                echo "WARNING: Could not extract max ops from $MAX_JSON, skipping rate-limited runs"
            fi
        else
            echo "WARNING: $MAX_JSON not found, skipping rate-limited runs"
        fi
    done
done

log "ALL BENCHMARKS COMPLETE (half=$HALF)"
echo "Results in results-mkt-*/ directories"
