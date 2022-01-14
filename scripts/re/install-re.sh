#!/bin/bash
source ips.sh
source defaults.sh

# exit immediately on error
set -e

for IP in $NODE1_EXT_IP $NODE2_EXT_IP; do
    echo "connecting to $IP using user $USER"
    ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} echo $IP
    scp -i ${PEM} license.txt ${USER}@${IP}:/tmp/license.txt
    scp -i ${PEM} install.sh ${USER}@${IP}:/tmp/i.sh
    scp -i ${PEM} $RE ${USER}@${IP}:/tmp/re.tar
    ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} sudo /tmp/i.sh
done
