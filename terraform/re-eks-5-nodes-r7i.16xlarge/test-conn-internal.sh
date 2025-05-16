#!/bin/bash
#
# test-conn-internal.sh - Test connection to Redis Enterprise Database from inside a pod
#
# This script tests the connection to the Redis Enterprise Database from inside a Redis Enterprise pod.
# It uses kubectl exec to run redis-cli inside the pod, which has direct access to the database.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"

echo "Testing connection to Redis Enterprise Database '$DB_NAME' from inside a pod..."

# Get the database port
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}')
if [ -z "$DB_PORT" ]; then
    echo "Error: Failed to get port for database '$DB_NAME'."
    exit 1
fi

echo "Database '$DB_NAME' is using port $DB_PORT."

# Get a Redis Enterprise pod name
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "app=redis-enterprise" -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
    echo "Error: Could not find any Redis Enterprise pods."
    exit 1
fi

echo "Using Redis Enterprise pod: $POD_NAME"

# Get the internal service name from the database status
DB_HOST=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].host}')
if [ -z "$DB_HOST" ]; then
    echo "Warning: Could not get internal hostname from database status."
    # Use the default format for Redis Enterprise Database internal service name
    DB_HOST="redis-$DB_PORT.$NAMESPACE.svc.cluster.local"
fi

# For Redis Enterprise Cluster, the correct format is:
# redis-<port>.<cluster-name>.<namespace>.svc.cluster.local
CLUSTER_NAME=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.redisEnterpriseCluster.name}')
if [ -n "$CLUSTER_NAME" ]; then
    CLUSTER_HOST="redis-$DB_PORT.$CLUSTER_NAME.$NAMESPACE.svc.cluster.local"
    echo "Using cluster-specific hostname: $CLUSTER_HOST"
    DB_HOST="$CLUSTER_HOST"
fi

echo "Using internal hostname: $DB_HOST"

# Get the Redis Enterprise password
PASSWORD=$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode)
if [ -z "$PASSWORD" ]; then
    echo "Warning: Could not retrieve the database password."
    echo "You may need to provide the password manually when connecting."
    AUTH_OPTION=""
else
    AUTH_OPTION="-a $PASSWORD"
fi

echo ""
echo "Connecting to Redis Enterprise Database from inside pod $POD_NAME..."
echo "Command: kubectl exec -it $POD_NAME -c redis-enterprise-node -n $NAMESPACE -- redis-cli -h $DB_HOST -p $DB_PORT $AUTH_OPTION"
echo ""

# Connect using redis-cli inside the pod
kubectl exec -it "$POD_NAME" -c redis-enterprise-node -n "$NAMESPACE" -- redis-cli -h "$DB_HOST" -p "$DB_PORT" $AUTH_OPTION

echo ""
echo "If the connection was successful, you should have been able to run Redis commands."
echo "If you encountered any issues, check the following:"
echo "1. Make sure the Redis Enterprise Cluster is running properly"
echo "2. Make sure the database is active and accessible"
echo "3. Make sure you have the correct permissions to access the database"
