#!/bin/bash
#
# update-db-settings.sh - Update Redis Enterprise Database settings
#
# This script updates the Redis Enterprise Database settings:
# 1. Changes the scheduling policy from "cmp" to "mnp" (Memory-Node-Policy)
# 2. Changes the connections parameter from 5 to 1
# 3. Enables/disables OSS Cluster API
#
# Usage: ./update-db-settings.sh [--sched-policy <policy>] [--conns <number>] [--oss-api <true|false>]
#
# Example: ./update-db-settings.sh --sched-policy mnp --conns 1 --oss-api true
#

# AWS credentials should be provided as environment variables
# export AWS_ACCESS_KEY_ID="your-access-key"
# export AWS_SECRET_ACCESS_KEY="your-secret-key"
# export AWS_SESSION_TOKEN="your-session-token"
# export AWS_REGION="us-east-2"

# Default values
SCHED_POLICY="mnp"
CONNS=1
OSS_API="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --sched-policy)
      SCHED_POLICY="$2"
      shift
      shift
      ;;
    --conns)
      CONNS="$2"
      shift
      shift
      ;;
    --oss-api)
      OSS_API="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done


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
echo "Getting current database configuration..."
DB_CONFIG=$(curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID)
echo "Scheduling policy: $(echo "$DB_CONFIG" | jq -r '.sched_policy')"
echo "Connections: $(echo "$DB_CONFIG" | jq -r '.conns')"
echo "OSS Cluster API: $(echo "$DB_CONFIG" | jq -r '.oss_cluster')"
echo "OSS Cluster API Preferred Endpoint Type: $(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_endpoint_type')"
echo "OSS Cluster API Preferred IP Type: $(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_ip_type')"

# Update the database settings
echo "Updating database settings..."
echo "  - Scheduling policy: $SCHED_POLICY"
echo "  - Connections: $CONNS"
echo "  - OSS Cluster API: $OSS_API"

curl -k -s -X PUT -u "$USERNAME:$PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"sched_policy\":\"$SCHED_POLICY\",\"conns\":$CONNS,\"oss_cluster\":$OSS_API}" \
  https://localhost:9443/v1/bdbs/$DB_UID > /dev/null

# Get the updated database configuration
echo "Getting updated database configuration..."
DB_CONFIG=$(curl -k -s -u "$USERNAME:$PASSWORD" https://localhost:9443/v1/bdbs/$DB_UID)
echo "Scheduling policy: $(echo "$DB_CONFIG" | jq -r '.sched_policy')"
echo "Connections: $(echo "$DB_CONFIG" | jq -r '.conns')"
echo "OSS Cluster API: $(echo "$DB_CONFIG" | jq -r '.oss_cluster')"
echo "OSS Cluster API Preferred Endpoint Type: $(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_endpoint_type')"
echo "OSS Cluster API Preferred IP Type: $(echo "$DB_CONFIG" | jq -r '.oss_cluster_api_preferred_ip_type')"

# Kill the port forwarding process
kill $PORT_FORWARD_PID

echo "Done."
