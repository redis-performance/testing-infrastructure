#!/bin/bash

set -e

echo "Starting node type scaling from cache.r7g.xlarge to cache.r7g.2xlarge..."

START_TIME=$(date +%s)

# Update node_type in ec.tf
sed -i 's/node_type.*=.*"cache\.r7g\.xlarge"/node_type                   = "cache.r7g.2xlarge"/' ec.tf

# Apply terraform changes
terraform apply -auto-approve

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "Scaling completed in ${DURATION} seconds"

