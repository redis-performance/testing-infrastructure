p#!/bin/bash
source ips.sh

# exit immediately on error
set -e

mkdir -p ./results-final-cleaned

for CLIENT_N in `seq 1 16`; do 
    vmtype=REDIS_VM_$CLIENT_N
    VM_TYPE="${!vmtype}"
    LOGNAME="$VM_TYPE-priority-10.log"
    echo "*************************************************************************************"
    cat ./results-final/$LOGNAME | grep memtier | grep AGGREGATED | grep Ops > ./results-final-cleaned/$LOGNAME
    echo "*************************************************************************************"
done

# wait

