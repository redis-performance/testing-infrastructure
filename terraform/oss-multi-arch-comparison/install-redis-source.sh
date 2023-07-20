#!/bin/bash
source ips.sh

# exit immediately on error
set -e

USER=ubuntu
PEM=${PEM:-"~/redislabs/pems/perf-ci.pem"}

for CLIENT_N in `seq 1 16`; do 
    eip=REDIS_$CLIENT_N\_E
    IP="${!eip}"
    echo "Working on host: $IP"
    # scp -o "StrictHostKeyChecking no"  -i ${PEM} build-redis.sh ${USER}@${IP}:/tmp/i.sh
    # ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} sudo /tmp/i.sh
    ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} redis-cli -p 16379 -a performance.redis ping
done

wait
