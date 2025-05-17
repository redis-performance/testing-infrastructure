#!/bin/bash
#
# update-conns.sh - Update Redis Enterprise Database connections parameter
#
# This script updates the Redis Enterprise Database connections parameter from 5 to 1
# using the Redis Enterprise REST API.
#


# Update kubeconfig
aws eks update-kubeconfig --region us-east-2 --name re-eks-cluster-5-nodes-r7i-16xlarge

# Set namespace
NAMESPACE="rec-large-scale"

# Get Redis Enterprise Cluster admin credentials
USERNAME=$(kubectl get secret rec-large-scale-5nodes -n $NAMESPACE -o jsonpath="{.data.username}" | base64 --decode)
PASSWORD=$(kubectl get secret rec-large-scale-5nodes -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode)

echo "Redis Enterprise Cluster admin credentials:"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"

# Get the database UID
DB_UID=$(kubectl get redb primary -n $NAMESPACE -o jsonpath="{.status.databaseUID}")
echo "Database UID: $DB_UID"

# Get one of the Redis Enterprise Cluster pods
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=redis-enterprise -o jsonpath="{.items[0].metadata.name}")
echo "Using Redis Enterprise pod: $POD_NAME"

# Set up port forwarding to the Redis Enterprise Cluster API
echo "Setting up port forwarding to the Redis Enterprise Cluster API..."
kubectl port-forward $POD_NAME -n $NAMESPACE 9443:9443 &
PORT_FORWARD_PID=$!

# Wait for port forwarding to be established
sleep 5

# Get the current database configuration
echo "Getting current database connections parameter..."
curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID | jq '.conns'

# Update the database connections parameter
echo "Updating database connections parameter from 5 to 1..."
curl -k -s -X PUT -u "$USERNAME:$PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"conns":1}' \
  https://localhost:9443/v1/bdbs/$DB_UID | jq .

# Get the updated database configuration
echo "Getting updated database connections parameter..."
curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID | jq '.conns'

# Kill the port forwarding process
kill $PORT_FORWARD_PID

echo "Done."
