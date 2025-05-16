#!/bin/bash
#
# test-with-temp-pod.sh - Test connection to Redis Enterprise Database using a temporary pod
#
# This script creates a temporary pod with redis-cli installed and uses it to test
# the connection to a Redis Enterprise Database.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
TEMP_POD_NAME="redis-cli-tester"

echo "=== Testing Connection to Redis Enterprise Database Using a Temporary Pod ==="
echo ""

# Get database information
echo "Step 1: Getting database information..."
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}' 2>/dev/null)
if [ -z "$DB_PORT" ]; then
    echo "Error: Failed to get port for database '$DB_NAME'."
    exit 1
fi
echo "Database port: $DB_PORT"

# Get the database secret name
echo "Step 2: Getting database secret name..."
SECRET_NAME=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath="{.spec.databaseSecretName}" 2>/dev/null)
if [ -z "$SECRET_NAME" ]; then
    # Default secret name format is redb-<database_name>
    SECRET_NAME="redb-$DB_NAME"
    echo "Could not get secret name from database spec, using default: $SECRET_NAME"
else
    echo "Database secret name: $SECRET_NAME"
fi

# Get the database password
echo "Step 3: Getting database password..."
PASSWORD=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.password}" | base64 --decode 2>/dev/null)
if [ -z "$PASSWORD" ]; then
    echo "Warning: Could not retrieve the database password."
    echo "You may need to provide the password manually when connecting."
    PASSWORD="VK7wvBPC"  # Default password, replace with your actual password if different
fi
echo "Database password retrieved."

# Get the service names from the secret
echo "Step 4: Getting service names..."
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

# Check if TLS is enabled for the database
echo "Step 5: Checking if TLS is enabled..."
TLS_MODE=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.tlsMode}' 2>/dev/null)
TLS_OPTIONS=""
if [ "$TLS_MODE" = "enabled" ] || [ "$TLS_MODE" = "required" ]; then
    echo "TLS is enabled for this database. Using --tls --insecure options."
    TLS_OPTIONS="--tls --insecure"
else
    echo "TLS is not enabled for this database."
fi

# Check if the temporary pod already exists
echo "Step 6: Checking if temporary pod already exists..."
POD_EXISTS=$(kubectl get pod "$TEMP_POD_NAME" -n "$NAMESPACE" 2>/dev/null)
if [ -n "$POD_EXISTS" ]; then
    echo "Temporary pod already exists. Deleting it..."
    kubectl delete pod "$TEMP_POD_NAME" -n "$NAMESPACE"
    echo "Waiting for pod to be deleted..."
    sleep 5
fi

# Create a temporary pod with redis-cli installed
echo "Step 7: Creating temporary pod with redis-cli installed..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $TEMP_POD_NAME
  namespace: $NAMESPACE
spec:
  containers:
  - name: redis-cli
    image: redis:latest
    command: ["sleep", "3600"]
EOF

echo "Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/"$TEMP_POD_NAME" -n "$NAMESPACE" --timeout=60s

# Test connection using redis-cli
echo "Step 8: Testing connection using redis-cli..."
echo "Command: kubectl exec -it $TEMP_POD_NAME -n $NAMESPACE -- redis-cli -h $DB_HOST -p $DB_PORT $TLS_OPTIONS -a $PASSWORD PING"
kubectl exec -it "$TEMP_POD_NAME" -n "$NAMESPACE" -- redis-cli -h "$DB_HOST" -p "$DB_PORT" $TLS_OPTIONS -a "$PASSWORD" PING

# Check the result
if [ $? -eq 0 ]; then
    echo ""
    echo "Connection successful!"
    echo ""
    echo "You can now use redis-cli to interact with the database:"
    echo "kubectl exec -it $TEMP_POD_NAME -n $NAMESPACE -- redis-cli -h $DB_HOST -p $DB_PORT $TLS_OPTIONS -a $PASSWORD"
else
    echo ""
    echo "Connection failed."
    echo ""
    echo "Let's try to diagnose the issue:"
    echo ""
    
    # Check if the service is resolvable
    echo "1. Checking if the service is resolvable..."
    kubectl exec -it "$TEMP_POD_NAME" -n "$NAMESPACE" -- nslookup "$DB_HOST" || echo "Service is not resolvable."
    
    # Check if the port is open
    echo ""
    echo "2. Checking if the port is open..."
    kubectl exec -it "$TEMP_POD_NAME" -n "$NAMESPACE" -- timeout 5 telnet "$DB_HOST" "$DB_PORT" || echo "Port is not open."
    
    # Check if the database is running
    echo ""
    echo "3. Checking if the database is running..."
    DB_STATUS=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.status}' 2>/dev/null)
    echo "Database status: $DB_STATUS"
    if [ "$DB_STATUS" != "active" ]; then
        echo "Warning: Database is not active. This could be causing the connection failure."
    fi
fi

# Clean up
echo ""
echo "Step 9: Cleaning up..."
echo "Would you like to delete the temporary pod? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Deleting temporary pod..."
    kubectl delete pod "$TEMP_POD_NAME" -n "$NAMESPACE"
    echo "Temporary pod deleted."
else
    echo "Keeping temporary pod for further testing."
    echo "You can delete it later with: kubectl delete pod $TEMP_POD_NAME -n $NAMESPACE"
fi

echo ""
echo "=== Connection Test Complete ==="
