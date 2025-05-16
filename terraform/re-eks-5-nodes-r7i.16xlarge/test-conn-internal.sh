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

# Get the database port from the secret
echo "Step 2: Retrieving the database port from the secret..."
DB_PORT=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.port}" | base64 --decode 2>/dev/null)
if [ -z "$DB_PORT" ]; then
    echo "Warning: Could not get port from secret. Trying to get it from database status..."
    DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}' 2>/dev/null)
    if [ -z "$DB_PORT" ]; then
        echo "Error: Failed to get port for database '$DB_NAME'."
        exit 1
    fi
fi
echo "Database port: $DB_PORT"

# Get the service names from the secret
echo "Step 3: Retrieving the service names from the secret..."
SERVICE_NAMES=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.service_names}" | base64 --decode 2>/dev/null)
if [ -z "$SERVICE_NAMES" ]; then
    echo "Warning: Could not get service names from secret. Trying to get hostname from database status..."
    DB_HOST=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].host}' 2>/dev/null)
    if [ -z "$DB_HOST" ]; then
        echo "Warning: Could not get hostname from database status. Using default service name..."
        DB_HOST="$DB_NAME"
    fi
else
    echo "Available service names: $SERVICE_NAMES"
    # Use the first service name in the list
    DB_HOST=$(echo "$SERVICE_NAMES" | cut -d ',' -f 1 | xargs)
    echo "Using service name: $DB_HOST"
fi

# Get the Redis Enterprise password from the secret
echo "Step 4: Retrieving the database password from the secret..."
PASSWORD=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.password}" | base64 --decode 2>/dev/null)
if [ -z "$PASSWORD" ]; then
    echo "Warning: Could not retrieve the database password."
    echo "You may need to provide the password manually when connecting."
    AUTH_OPTION=""
else
    echo "Database password retrieved successfully."
    AUTH_OPTION="-a $PASSWORD"
fi

# Get a Redis Enterprise pod name
echo "Step 5: Finding a Redis Enterprise pod to connect from..."
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "app=redis-enterprise" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POD_NAME" ]; then
    echo "Error: Could not find any Redis Enterprise pods."
    exit 1
fi
echo "Using Redis Enterprise pod: $POD_NAME"

echo ""
echo "Connecting to Redis Enterprise Database from inside pod $POD_NAME..."
echo ""

# Check if TLS is enabled for the database
TLS_MODE=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tlsMode}' 2>/dev/null)
TLS_OPTIONS=""
if [ "$TLS_MODE" = "enabled" ] || [ "$TLS_MODE" = "required" ]; then
    echo "TLS is enabled for this database. Using --tls --insecure options."
    TLS_OPTIONS="--tls --insecure"
else
    echo "TLS is not enabled for this database."
fi

if [ -n "$PASSWORD" ]; then
    echo "Method 1: Using the -a option to provide the password (recommended):"
    echo "Command: kubectl exec -it $POD_NAME -c redis-enterprise-node -n $NAMESPACE -- redis-cli -h $DB_HOST -p $DB_PORT $TLS_OPTIONS $AUTH_OPTION"
    echo ""

    # Connect using redis-cli inside the pod with the password
    kubectl exec -it "$POD_NAME" -c redis-enterprise-node -n "$NAMESPACE" -- redis-cli -h "$DB_HOST" -p "$DB_PORT" $TLS_OPTIONS $AUTH_OPTION
else
    echo "Method 2: Using the auth command to provide the password:"
    echo "Command: kubectl exec -it $POD_NAME -c redis-enterprise-node -n $NAMESPACE -- redis-cli -h $DB_HOST -p $DB_PORT $TLS_OPTIONS"
    echo "Then enter: auth <password>"
    echo ""

    # Connect using redis-cli inside the pod without the password
    kubectl exec -it "$POD_NAME" -c redis-enterprise-node -n "$NAMESPACE" -- redis-cli -h "$DB_HOST" -p "$DB_PORT" $TLS_OPTIONS
fi

echo ""
echo "If the connection was successful, you should have been able to run Redis commands."
echo "If you encountered any issues, check the following:"
echo "1. Make sure the Redis Enterprise Cluster is running properly"
echo "2. Make sure the database is active and accessible"
echo "3. Make sure you have the correct permissions to access the database"
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
