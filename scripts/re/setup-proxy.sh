#!/bin/bash

source ips.sh
source defaults.sh

for IP in $NODE1_EXT_IP $NODE2_EXT_IP; do
    # Adjust proxy threads
    ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} sudo \
        /opt/redislabs/bin/rladmin tune proxy all threads $PROXY_THREADS max_threads $PROXY_THREADS
    
    ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} sudo \
        /opt/redislabs/bin/dmc_ctl restart
done
