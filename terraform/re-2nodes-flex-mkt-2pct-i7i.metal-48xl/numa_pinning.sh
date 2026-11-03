#!/bin/bash
set -euo pipefail

# NUMA half/half pinning for i7i.metal-48xl (2 sockets, 96 cores each)
# Socket 0: CPUs 0-47,96-143
# Socket 1: CPUs 48-95,144-191

apt-get install -y numactl > /dev/null 2>&1 || true

# Wait for shards to be ready
sleep 30

# Split shards: first half -> socket 0, second half -> socket 1
PIDS=($(pgrep -f redis-server-8.4 | sort -n))
TOTAL=${#PIDS[@]}
HALF=$((TOTAL / 2))

for i in $(seq 0 $((HALF - 1))); do
    migratepages ${PIDS[$i]} 1 0 2>/dev/null || true
    taskset -acp 0-47,96-143 ${PIDS[$i]} > /dev/null 2>&1
done
echo "$HALF shards pinned to socket 0"

for i in $(seq $HALF $((TOTAL - 1))); do
    migratepages ${PIDS[$i]} 0 1 2>/dev/null || true
    taskset -acp 48-95,144-191 ${PIDS[$i]} > /dev/null 2>&1
done
echo "$((TOTAL - HALF)) shards pinned to socket 1"

# dmcproxy workers: 16/16 split across sockets
DMP_PID=$(pgrep dmcproxy | head -1)
for tid in $(ls /proc/$DMP_PID/task/ | sort -n); do
    name=$(cat /proc/$DMP_PID/task/$tid/comm 2>/dev/null) || continue
    case "$name" in
        worker-[0-9]|worker-1[0-5])
            taskset -cp 0-47,96-143 $tid > /dev/null 2>&1 ;;
        worker-1[6-9]|worker-2[0-9]|worker-3[01])
            taskset -cp 48-95,144-191 $tid > /dev/null 2>&1 ;;
        *)
            taskset -cp 0-47,96-143 $tid > /dev/null 2>&1 ;;
    esac
done
echo "dmcproxy: 16 workers socket 0, 16 workers socket 1, mgmt socket 0"

# Network IRQs -> split across both sockets
NIC=$(ip -br link | grep UP | grep -v lo | awk '{print $1}')
IRQS=($(grep "$NIC" /proc/interrupts | awk -F: '{print $1}' | tr -d ' '))
HIRQ=$((${#IRQS[@]} / 2))

for i in $(seq 0 $((HIRQ - 1))); do
    echo '0-47,96-143' > /proc/irq/${IRQS[$i]}/smp_affinity_list 2>/dev/null || true
done
for i in $(seq $HIRQ $((${#IRQS[@]} - 1))); do
    echo '48-95,144-191' > /proc/irq/${IRQS[$i]}/smp_affinity_list 2>/dev/null || true
done
echo "Network IRQs: split across both sockets"

echo "NUMA pinning (half/half) completed successfully!"
