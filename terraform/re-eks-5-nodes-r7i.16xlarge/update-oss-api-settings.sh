#!/bin/bash
#
# update-oss-api-settings.sh - Update OSS Cluster API settings
#
# This script updates the OSS Cluster API settings for a Redis Enterprise Database
# using the Redis Enterprise REST API.
#

# AWS credentials should be provided as environment variables
# export AWS_ACCESS_KEY_ID="your-access-key"
# export AWS_SECRET_ACCESS_KEY="your-secret-key"
# export AWS_SESSION_TOKEN="your-session-token"
# export AWS_REGION="us-east-2"

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

# Get the current OSS Cluster API settings
echo "Getting current OSS Cluster API settings..."
DB_CONFIG=$(curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID)
OSS_CLUSTER=$(echo "$DB_CONFIG" | jq -r '.oss_cluster')
OSS_ENDPOINT_TYPE=$(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_endpoint_type')
OSS_IP_TYPE=$(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_ip_type')

echo "OSS Cluster API: $OSS_CLUSTER"
echo "OSS Cluster API Preferred Endpoint Type: $OSS_ENDPOINT_TYPE"
echo "OSS Cluster API Preferred IP Type: $OSS_IP_TYPE"

# Update the OSS Cluster API settings
echo "Updating OSS Cluster API settings..."
echo "  - OSS Cluster API: true"
echo "  - OSS Cluster API Preferred Endpoint Type: ip"
echo "  - OSS Cluster API Preferred IP Type: external"

curl -k -s -X PUT -u "$USERNAME:$PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"oss_cluster":true,"oss_cluster_api_preferred_endpoint_type":"ip","oss_cluster_api_preferred_ip_type":"external"}' \
  https://localhost:9443/v1/bdbs/$DB_UID > /dev/null

# Get the updated OSS Cluster API settings
echo "Getting updated OSS Cluster API settings..."
DB_CONFIG=$(curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID)
OSS_CLUSTER=$(echo "$DB_CONFIG" | jq -r '.oss_cluster')
OSS_ENDPOINT_TYPE=$(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_endpoint_type')
OSS_IP_TYPE=$(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_ip_type')

echo "OSS Cluster API: $OSS_CLUSTER"
echo "OSS Cluster API Preferred Endpoint Type: $OSS_ENDPOINT_TYPE"
echo "OSS Cluster API Preferred IP Type: $OSS_IP_TYPE"

# Kill the port forwarding process
kill $PORT_FORWARD_PID

echo "Done."
