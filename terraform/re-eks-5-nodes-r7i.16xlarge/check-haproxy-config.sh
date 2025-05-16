#!/bin/bash
#
# check-haproxy-config.sh - Check HAProxy Ingress configuration
#
# This script checks the HAProxy Ingress configuration to make sure it's properly set up
# for routing traffic to the Redis Enterprise Database.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
INGRESS_NAME="primary-haproxy-ingress"

echo "Checking HAProxy Ingress configuration for Redis Enterprise Database '$DB_NAME'..."

# Check if HAProxy Ingress is installed
echo "Checking if HAProxy Ingress is installed..."
HAPROXY_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$HAPROXY_POD" ]; then
    echo "Error: HAProxy Ingress is not installed or not running."
    echo "Please run ./haproxy.sh to install HAProxy Ingress."
    exit 1
fi

echo "HAProxy Ingress is installed and running."
echo "HAProxy pod: $HAPROXY_POD"

# Check if the LoadBalancer service is available
echo ""
echo "Checking if the LoadBalancer service is available..."
LB_HOSTNAME=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -z "$LB_HOSTNAME" ]; then
    echo "Error: LoadBalancer hostname is not available."
    echo "Please check the HAProxy Ingress service status:"
    kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress"
    exit 1
fi

echo "LoadBalancer hostname: $LB_HOSTNAME"

# Check if the Ingress resource exists
echo ""
echo "Checking if the Ingress resource exists..."
INGRESS_EXISTS=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" 2>/dev/null)
if [ -z "$INGRESS_EXISTS" ]; then
    echo "Error: Ingress resource '$INGRESS_NAME' does not exist."
    echo "Please run ./apply-primary-haproxy.sh to create the Ingress resource."
    exit 1
fi

echo "Ingress resource '$INGRESS_NAME' exists."

# Check the Ingress configuration
echo ""
echo "Checking Ingress configuration..."
INGRESS_HOST=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
INGRESS_PORT=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)
INGRESS_SERVICE=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)

echo "Ingress host: $INGRESS_HOST"
echo "Ingress port: $INGRESS_PORT"
echo "Ingress service: $INGRESS_SERVICE"

# Get the database port
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}' 2>/dev/null)
if [ -z "$DB_PORT" ]; then
    echo "Warning: Could not get port for database '$DB_NAME'."
    echo "Please check if the database exists and is active."
else
    echo "Database port: $DB_PORT"
    
    # Check if the Ingress port matches the database port
    if [ "$INGRESS_PORT" != "$DB_PORT" ]; then
        echo "Warning: Ingress port ($INGRESS_PORT) does not match database port ($DB_PORT)."
        echo "Please update the primary-haproxy.yaml file with the correct port and apply it again."
    else
        echo "Ingress port matches database port."
    fi
fi

# Check if the Ingress service matches the database name
if [ "$INGRESS_SERVICE" != "$DB_NAME" ]; then
    echo "Warning: Ingress service ($INGRESS_SERVICE) does not match database name ($DB_NAME)."
    echo "Please update the primary-haproxy.yaml file with the correct service name and apply it again."
else
    echo "Ingress service matches database name."
fi

# Check HAProxy Ingress logs
echo ""
echo "Checking HAProxy Ingress logs for any errors..."
kubectl logs "$HAPROXY_POD" -n "$NAMESPACE" --tail=20 | grep -i error || echo "No errors found in the logs."

echo ""
echo "HAProxy Ingress configuration check completed."
echo ""
echo "If everything looks good, you should be able to connect to the database using:"
echo "redis-cli -h $LB_HOSTNAME -p $DB_PORT --tls --insecure --sni $DB_NAME.$LB_HOSTNAME -a <password>"
echo ""
echo "If you're still having issues connecting, try the following:"
echo "1. Check if the database is accessible from inside the cluster using ./test-conn-internal.sh"
echo "2. Check if there are any network policies or security groups blocking the connection"
echo "3. Make sure the HAProxy Ingress controller is properly configured for SSL passthrough"
