#!/bin/bash
#
# test-conn-primary.sh - Test external access to Redis Enterprise Database
#
# This script tests the external access to the primary Redis Enterprise Database using OpenSSL.
# It retrieves the CA certificate from a Redis Enterprise pod and uses it to establish
# a secure connection to the database through the HAProxy Ingress.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
CERT_FILE="proxy_cert.pem"
USE_LB_HOSTNAME=true  # Set to false to use the Ingress hostname (primary-db.example.com)

echo "Testing connection to Redis Enterprise Database '$DB_NAME'..."

# Get the database port
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}')
if [ -z "$DB_PORT" ]; then
    echo "Error: Failed to get port for database '$DB_NAME'."
    exit 1
fi

echo "Database '$DB_NAME' is using port $DB_PORT."

# Get the database hostname
if [ "$USE_LB_HOSTNAME" = true ]; then
    # Use the LoadBalancer hostname directly (not with subdomain)
    if [ -f "haproxy_hostname.txt" ]; then
        LB_HOSTNAME=$(cat haproxy_hostname.txt)
        DB_HOST="$LB_HOSTNAME"
        echo "Note: Using the LoadBalancer hostname directly."
        echo "You'll need to use the Host header when connecting."
    else
        echo "Error: LoadBalancer hostname file not found."
        echo "Please run ./haproxy.sh first to set up HAProxy Ingress."
        exit 1
    fi
else
    # Use the Ingress hostname
    DB_HOST="primary-db.example.com"
fi

echo "Using hostname: $DB_HOST"

# Get a Redis Enterprise pod name
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "app=redis-enterprise" -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
    echo "Error: Could not find any Redis Enterprise pods."
    exit 1
fi

echo "Using Redis Enterprise pod: $POD_NAME"

# Get the CA certificate from the Redis Enterprise pod
echo "Retrieving CA certificate from Redis Enterprise pod..."
kubectl exec -it "$POD_NAME" -c redis-enterprise-node -n "$NAMESPACE" -- cat /etc/opt/redislabs/proxy_cert.pem > "$CERT_FILE"

echo "CA certificate saved to $CERT_FILE"

# Test the connection using OpenSSL
echo ""
echo "Testing connection to $DB_HOST:443 using OpenSSL..."
echo "Press Ctrl+C to exit after testing."
echo ""
echo "Type 'PING' and press Enter to test the connection."
echo "You should receive '+PONG' in response if the connection is successful."
echo ""

# Set the SNI hostname
if [ "$USE_LB_HOSTNAME" = true ]; then
    SNI_HOST="primary.$DB_HOST"
else
    SNI_HOST="$DB_HOST"
fi

echo "Using SNI hostname: $SNI_HOST"
echo ""

# Run OpenSSL client
openssl s_client \
  -connect "$DB_HOST:443" \
  -crlf -CAfile "./$CERT_FILE" \
  -servername "$SNI_HOST" \
  -verify_hostname "$SNI_HOST"

# Clean up
echo ""
echo "Cleaning up..."
rm -f "$CERT_FILE"
echo "Done."
