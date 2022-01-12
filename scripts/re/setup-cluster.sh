#!/bin/bash

source ips.sh
source defaults.sh

IP=$NODE1_EXT_IP
REMOTE_MOD_ARTIFACT=/tmp/rejson.zip

scp -i ${PEM} license.txt ${USER}@${IP}:/tmp/license.txt
scp -i ${PEM} $REJSON_ARTIFACT ${USER}@${IP}:$REMOTE_MOD_ARTIFACT

ssh -i ${PEM} -t ${USER}@${IP} sudo \
    /opt/redislabs/bin/rladmin cluster create name $CLUSTER_NAME \
    username $U password $P license_file /tmp/license.txt

# join cluster
for IP in $NODE2_EXT_IP; do
    ssh -o "StrictHostKeyChecking no" -i ${PEM} -t ${USER}@${IP} sudo \
        /opt/redislabs/bin/rladmin cluster join nodes ${NODE1_INT_IP} \
        username $U password $P
done

# upload module
ssh -i ${PEM} -t ${USER}@${NODE1_EXT_IP} sudo \
    curl -k -v -u "$U:$P" -F "module=@${REMOTE_MOD_ARTIFACT}" https://localhost:9443/v1/modules
