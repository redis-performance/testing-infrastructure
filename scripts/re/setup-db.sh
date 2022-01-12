#!/bin/bash

source ips.sh
source defaults.sh

set -x

DB_DETAILS_JSON=/tmp/create.json
scp -i ${PEM} db-details.json ${USER}@${NODE1_EXT_IP}:$DB_DETAILS_JSON

# upload module
ssh -i ${PEM} -t ${USER}@${NODE1_EXT_IP} sudo \
    curl -k -v -u "$U:$P" --location-trusted https://localhost:9443/v1/bdbs -H "Content-type:application/json" --data "@/${DB_DETAILS_JSON}"
