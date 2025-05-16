#!/bin/bash
#
# redis-cli-instructions.sh - Provide instructions for connecting to Redis Enterprise Database using redis-cli
#
# This script provides instructions for connecting to the Redis Enterprise Database using redis-cli.
# It retrieves the database port, hostname, and password, and provides detailed connection instructions.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"

echo "Instructions for connecting to Redis Enterprise Database '$DB_NAME' using redis-cli..."

# Get the database port
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}')
if [ -z "$DB_PORT" ]; then
    echo "Error: Failed to get port for database '$DB_NAME'."
    exit 1
fi

echo "Database '$DB_NAME' is using port $DB_PORT."

# Get the LoadBalancer hostname
if [ -f "haproxy_hostname.txt" ]; then
    LB_HOSTNAME=$(cat haproxy_hostname.txt)
else
    echo "Warning: LoadBalancer hostname file not found."
    echo "Please run ./haproxy.sh first to set up HAProxy Ingress."
    LB_HOSTNAME="<LoadBalancer hostname>"
fi

# Get the Redis Enterprise password
PASSWORD=$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode)
if [ -z "$PASSWORD" ]; then
    echo "Warning: Could not retrieve the database password."
    echo "You may need to provide the password manually when connecting."
    PASSWORD="<password>"
fi

echo ""
echo "To connect to the Redis Enterprise Database using redis-cli, follow these steps:"
echo ""
echo "1. Install redis-cli if you haven't already:"
echo "   Ubuntu/Debian: sudo apt-get install redis-tools"
echo "   CentOS/RHEL: sudo yum install redis"
echo "   macOS: brew install redis"
echo ""
echo "2. Since we're using the --insecure option, we don't need the CA certificate."
echo "   (Skip this step if you're using the insecure option)"
echo "   # To get the CA certificate if needed:"
echo "   # kubectl exec -it \$(kubectl get pods -n $NAMESPACE -l app=redis-enterprise -o jsonpath='{.items[0].metadata.name}') -c redis-enterprise-node -n $NAMESPACE -- cat /etc/opt/redislabs/proxy_cert.pem > ca.crt"
echo ""
echo "3. Connect using redis-cli:"
echo ""
echo "   # Using the LoadBalancer hostname with insecure TLS (no certificate verification):"
echo "   redis-cli -h $LB_HOSTNAME -p $DB_PORT --tls --insecure --sni $DB_NAME.$LB_HOSTNAME -a '$PASSWORD'"
echo ""
echo "   # Or using the Ingress hostname with insecure TLS (requires DNS or /etc/hosts entry):"
echo "   redis-cli -h primary-db.example.com -p $DB_PORT --tls --insecure -a '$PASSWORD'"
echo ""
echo "   # If you want to use certificate verification, get the CA certificate first:"
echo "   # kubectl exec -it \$(kubectl get pods -n $NAMESPACE -l app=redis-enterprise -o jsonpath='{.items[0].metadata.name}') -c redis-enterprise-node -n $NAMESPACE -- cat /etc/opt/redislabs/proxy_cert.pem > ca.crt"
echo "   # redis-cli -h $LB_HOSTNAME -p $DB_PORT --tls --sni $DB_NAME.$LB_HOSTNAME --cacert ca.crt -a '$PASSWORD'"
echo ""
echo "4. Once connected, you can run Redis commands like:"
echo "   PING"
echo "   SET key value"
echo "   GET key"
echo ""
echo "5. Clean up the certificate file when done (if you created one):"
echo "   # rm -f ca.crt"
echo ""
echo "Note: If you're having trouble connecting, make sure that:"
echo "1. The HAProxy Ingress is properly configured (run ./haproxy.sh)"
echo "2. The primary-haproxy.yaml file has been applied (run ./apply-primary-haproxy.sh)"
echo "3. The port in primary-haproxy.yaml matches the database port ($DB_PORT)"
echo "4. You're using the correct hostname and SNI value"
