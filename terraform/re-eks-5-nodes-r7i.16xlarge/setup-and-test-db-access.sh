#!/bin/bash
#
# setup-and-test-db-access.sh - Set up and test external access to Redis Enterprise Database
#
# This script applies the primary-haproxy.yaml file to set up external access to the primary database,
# and provides instructions for testing the connection.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
INGRESS_FILE="primary-haproxy.yaml"
CERT_FILE="proxy_cert.pem"

echo "Setting up external access to Redis Enterprise Database '$DB_NAME'..."

# Check if the Ingress file exists
if [ ! -f "$INGRESS_FILE" ]; then
    echo "Error: Ingress file '$INGRESS_FILE' not found."
    exit 1
fi

# Apply the Ingress configuration
echo "Applying Ingress configuration from $INGRESS_FILE..."
kubectl apply -f "$INGRESS_FILE"

# Get the database hostname from the Ingress resource
echo "Getting database hostname..."
DB_HOST=$(kubectl get ingress "primary-haproxy-ingress" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}')
if [ -z "$DB_HOST" ]; then
    echo "Warning: Could not get hostname from Ingress resource."
    echo "Using default hostname: primary-db.example.com"
    DB_HOST="primary-db.example.com"
fi

# Get the database port from the Ingress resource
echo "Getting database port..."
DB_PORT=$(kubectl get ingress "primary-haproxy-ingress" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}')
if [ -z "$DB_PORT" ]; then
    echo "Warning: Could not get port from Ingress resource."
    echo "Using default port: 11793"
    DB_PORT="11793"
fi

echo ""
echo "External access to Redis Enterprise Database '$DB_NAME' has been set up."
echo ""
echo "Database hostname: $DB_HOST"
echo "Database port: $DB_PORT"
echo ""
echo "To test the connection, follow these steps:"
echo ""
echo "1. Get the CA certificate from a Redis Enterprise pod:"
echo ""
echo "   POD_NAME=\$(kubectl get pods -n $NAMESPACE -l app=redis-enterprise -o jsonpath='{.items[0].metadata.name}')"
echo "   kubectl exec -it \$POD_NAME -c redis-enterprise-node -n $NAMESPACE -- cat /etc/opt/redislabs/proxy_cert.pem > $CERT_FILE"
echo ""
echo "2. Test the connection using OpenSSL:"
echo ""
echo "   openssl s_client \\"
echo "     -connect $DB_HOST:443 \\"
echo "     -crlf -CAfile ./$CERT_FILE \\"
echo "     -servername $DB_HOST"
echo ""
echo "3. Once connected, type 'PING' and press Enter. You should receive '+PONG' in response."
echo ""
echo "4. Clean up the certificate file when done:"
echo ""
echo "   rm -f $CERT_FILE"
echo ""
echo "Note: If you cannot connect to $DB_HOST, you may need to add an entry to your /etc/hosts file"
echo "or use the LoadBalancer hostname instead."
echo ""
echo "LoadBalancer hostname: $(cat haproxy_hostname.txt 2>/dev/null || echo "<not available>")"
echo "You can use: primary.$(cat haproxy_hostname.txt 2>/dev/null || echo "<LoadBalancer hostname not available>")"
