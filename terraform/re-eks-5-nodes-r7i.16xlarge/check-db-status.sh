#!/bin/bash
#
# check-db-status.sh - Check Redis Enterprise Database status
#
# This script checks the status of a Redis Enterprise Database and provides
# detailed information about the database configuration and endpoints.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"

echo "Checking Redis Enterprise Database '$DB_NAME' status..."

# Check if the database exists
DB_EXISTS=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" 2>/dev/null)
if [ -z "$DB_EXISTS" ]; then
    echo "Error: Redis Enterprise Database '$DB_NAME' not found in namespace '$NAMESPACE'."
    echo "Available databases:"
    kubectl get redb -n "$NAMESPACE"
    exit 1
fi

# Get database status
echo ""
echo "Database status:"
kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o wide

# Get database details
echo ""
echo "Database details:"
kubectl describe redb "$DB_NAME" -n "$NAMESPACE"

# Get database endpoints
echo ""
echo "Database endpoints:"
ENDPOINTS=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints}')
echo "$ENDPOINTS" | jq -r '.'

# Get database port
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}')
if [ -z "$DB_PORT" ]; then
    echo "Warning: Could not get port for database '$DB_NAME'."
else
    echo ""
    echo "Database port: $DB_PORT"
fi

# Get database hostname
DB_HOST=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].host}')
if [ -z "$DB_HOST" ]; then
    echo "Warning: Could not get hostname for database '$DB_NAME'."
else
    echo "Database hostname: $DB_HOST"
fi

# Get database services
echo ""
echo "Database services:"
kubectl get svc -n "$NAMESPACE" -l "app=redis-enterprise"

# Get database pods
echo ""
echo "Redis Enterprise pods:"
kubectl get pods -n "$NAMESPACE" -l "app=redis-enterprise"

# Get database secrets
echo ""
echo "Database secrets:"
kubectl get secret "redb-$DB_NAME" -n "$NAMESPACE" -o yaml

# Get database password
PASSWORD=$(kubectl get secret "redb-$DB_NAME" -n "$NAMESPACE" -o jsonpath="{.data.password}" | base64 --decode)
if [ -z "$PASSWORD" ]; then
    echo "Warning: Could not get password for database '$DB_NAME'."
else
    echo ""
    echo "Database password: $PASSWORD"
fi

# Get Ingress resources
echo ""
echo "Ingress resources:"
kubectl get ingress -n "$NAMESPACE" | grep -i "$DB_NAME" || echo "No Ingress resources found for database '$DB_NAME'."

# Get HAProxy Ingress service
echo ""
echo "HAProxy Ingress service:"
kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress"

# Get LoadBalancer hostname
LB_HOSTNAME=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -z "$LB_HOSTNAME" ]; then
    echo "Warning: Could not get LoadBalancer hostname."
else
    echo ""
    echo "LoadBalancer hostname: $LB_HOSTNAME"
fi

echo ""
echo "Database status check completed."
echo ""
echo "To connect to the database from inside the cluster, use:"
echo "redis-cli -h $DB_HOST -p $DB_PORT -a $PASSWORD"
echo ""
echo "To connect to the database from outside the cluster, use:"
echo "redis-cli -h $LB_HOSTNAME -p $DB_PORT --tls --insecure --sni $DB_NAME.$LB_HOSTNAME -a $PASSWORD"
