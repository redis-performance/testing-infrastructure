#!/bin/bash
#
# test-conn-simple.sh - Simple test for external access to Redis Enterprise Database
#

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
CERT_FILE="proxy_cert.pem"

# Get the database port
echo "Getting database port..."
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}')
echo "Database port: $DB_PORT"

# Get the database hostname
echo "Getting database hostname..."
INGRESS_NAME="primary-haproxy-ingress-$DB_NAME"
DB_HOST=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}')
echo "Database hostname: $DB_HOST"

# Get a Redis Enterprise pod name
echo "Getting Redis Enterprise pod..."
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "app=redis-enterprise" -o jsonpath='{.items[0].metadata.name}')
echo "Pod name: $POD_NAME"

# Get the CA certificate from the Redis Enterprise pod
echo "Retrieving CA certificate..."
kubectl exec -it "$POD_NAME" -c redis-enterprise-node -n "$NAMESPACE" -- cat /etc/opt/redislabs/proxy_cert.pem > "$CERT_FILE"
echo "CA certificate saved to $CERT_FILE"

# Test the connection using OpenSSL
echo ""
echo "Testing connection to $DB_HOST:443 using OpenSSL..."
echo "Press Ctrl+C to exit after testing."
echo "Type 'PING' and press Enter to test the connection."
echo ""

# Run OpenSSL client
openssl s_client \
  -connect "$DB_HOST:443" \
  -crlf -CAfile "./$CERT_FILE" \
  -servername "$DB_HOST"

# Clean up
rm -f "$CERT_FILE"
echo "Done."
