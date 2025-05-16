#!/bin/bash
#
# test-conn-pod.sh - Test connection to Redis Enterprise Database from inside a pod
#
# This script tests the connection to the Redis Enterprise Database from inside a Redis Enterprise pod.
# It uses kubectl exec to run redis-cli inside the pod, which already has access to the CA certificate.
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

# Get the database secret name
echo "Step 1: Retrieving the database secret name..."
SECRET_NAME=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.databaseSecretName}" 2>/dev/null)
if [ -z "$SECRET_NAME" ]; then
    # Default secret name format is redb-<database_name>
    SECRET_NAME="redb-$DB_NAME"
    echo "Could not get secret name from database spec, using default: $SECRET_NAME"
else
    echo "Database secret name: $SECRET_NAME"
fi

# Get the service names from the secret
echo "Step 2: Retrieving the service names from the secret..."
SERVICE_NAMES=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.service_names}" | base64 --decode 2>/dev/null)
if [ -z "$SERVICE_NAMES" ]; then
    echo "Warning: Could not get service names from secret. Trying to get hostname from database status..."
    DB_HOST=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].host}' 2>/dev/null)
    if [ -z "$DB_HOST" ]; then
        echo "Warning: Could not get hostname from database status. Using default service name..."

        # Get the cluster name
        CLUSTER_NAME=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.redisEnterpriseCluster.name}' 2>/dev/null)
        if [ -n "$CLUSTER_NAME" ]; then
            DB_HOST="redis-$DB_PORT.$CLUSTER_NAME.$NAMESPACE.svc.cluster.local"
        else
            DB_HOST="redis-$DB_PORT.$NAMESPACE.svc.cluster.local"
        fi
    fi
else
    echo "Available service names: $SERVICE_NAMES"
    # Use the first service name in the list
    DB_HOST=$(echo "$SERVICE_NAMES" | cut -d ',' -f 1 | xargs)
    echo "Using service name: $DB_HOST"
fi

echo "Using internal hostname: $DB_HOST"

# Check if TLS is enabled for the database
echo "Step 3: Checking if TLS is enabled..."
TLS_MODE=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tlsMode}' 2>/dev/null)
TLS_OPTIONS=""
if [ "$TLS_MODE" = "enabled" ] || [ "$TLS_MODE" = "required" ]; then
    echo "TLS is enabled for this database. Using --tls --insecure options."
    TLS_OPTIONS="--tls --insecure"
else
    echo "TLS is not enabled for this database."
fi

# Get the Redis Enterprise password
echo "Step 4: Retrieving the database password..."
PASSWORD=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.password}" | base64 --decode 2>/dev/null)
if [ -z "$PASSWORD" ]; then
    echo "Warning: Could not retrieve the database password."
    echo "You may need to provide the password manually when connecting."
    PASSWORD=""
    AUTH_OPTION=""
else
    echo "Database password retrieved successfully."
    AUTH_OPTION="-a $PASSWORD"
fi

echo ""
echo "Connecting to Redis Enterprise Database from inside pod $POD_NAME..."
echo "Command: redis-cli -h $DB_HOST -p $DB_PORT $TLS_OPTIONS $AUTH_OPTION"
echo ""
echo "Once connected, you can run Redis commands like:"
echo "PING"
echo "SET key value"
echo "GET key"
echo ""

# Connect using redis-cli inside the pod
kubectl exec -it "$POD_NAME" -c redis-enterprise-node -n "$NAMESPACE" -- bash -c "redis-cli -h $DB_HOST -p $DB_PORT $TLS_OPTIONS $AUTH_OPTION"

echo ""
echo "Connection information summary:"
echo "- Secret name: $SECRET_NAME"
echo "- Service name: $DB_HOST"
echo "- Port: $DB_PORT"
echo "- TLS mode: $(if [ -n "$TLS_MODE" ]; then echo "$TLS_MODE"; else echo "<not retrieved>"; fi)"
echo "- TLS options: $(if [ -n "$TLS_OPTIONS" ]; then echo "$TLS_OPTIONS"; else echo "none"; fi)"
echo "- Password: $(if [ -n "$PASSWORD" ]; then echo "$PASSWORD"; else echo "<not retrieved>"; fi)"
echo ""
echo "To connect manually, use:"
echo "redis-cli -h $DB_HOST -p $DB_PORT $TLS_OPTIONS -a \"$PASSWORD\""
