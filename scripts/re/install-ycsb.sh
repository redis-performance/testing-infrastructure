#!/bin/bash
source ips.sh
source defaults.sh 


for IP in $CLIENT_EIP; do
    echo $IP
    scp -i ${PEM} ycsb.sh ${USER}@${IP}:/tmp/i.sh
    ssh -i ${PEM} -t ${USER}@${IP} sudo /tmp/i.sh
done

