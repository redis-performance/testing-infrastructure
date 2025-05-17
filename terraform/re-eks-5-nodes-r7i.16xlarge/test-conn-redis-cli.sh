#!/bin/bash
#
# test-conn-redis-cli.sh - Test connection to Redis Enterprise Database using redis-cli
#
# This script tests the connection to the Redis Enterprise Database using redis-cli.
# It retrieves the database port and hostname, and provides instructions for connecting.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
USE_LB_HOSTNAME=true  # Set to false to use the Ingress hostname (primary-db.example.com)

echo "Testing connection to Redis Enterprise Database '$DB_NAME' using redis-cli..."

# Get the database port
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}')
if [ -z "$DB_PORT" ]; then
    echo "Error: Failed to get port for database '$DB_NAME'."
    exit 1
fi

echo "Database '$DB_NAME' is using port $DB_PORT."

# Get the database hostname
if [ "$USE_LB_HOSTNAME" = true ]; then
    # Use the LoadBalancer hostname
    if [ -f "haproxy_hostname.txt" ]; then
        LB_HOSTNAME=$(cat haproxy_hostname.txt)
        DB_HOST="$LB_HOSTNAME"
        SNI_HOST="$DB_NAME.$LB_HOSTNAME"
    else
        echo "Error: LoadBalancer hostname file not found."
        echo "Please run ./haproxy.sh first to set up HAProxy Ingress."
        exit 1
    fi
else
    # Use the Ingress hostname
    DB_HOST="primary-db.example.com"
    SNI_HOST="$DB_HOST"
fi

echo "Using hostname: $DB_HOST"
echo "Using SNI hostname: $SNI_HOST"

# Check if redis-cli is installed
if ! command -v redis-cli &> /dev/null; then
    echo "Error: redis-cli is not installed."
    echo "Please install redis-cli using your package manager."
    echo "For example: sudo apt-get install redis-tools"
    exit 1
fi

# Get the Redis Enterprise password
PASSWORD=$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode)
if [ -z "$PASSWORD" ]; then
    echo "Warning: Could not retrieve the database password."
    echo "You may need to provide the password manually when connecting."
    PASSWORD="<password>"
fi

echo ""
echo "To connect to the Redis Enterprise Database using redis-cli, run the following command:"
echo ""
echo "redis-cli -h $DB_HOST -p $DB_PORT --tls --sni $SNI_HOST --cacert /path/to/ca.crt -a '$PASSWORD'"
echo ""
echo "Note: You need to provide the CA certificate file. You can get it from a Redis Enterprise pod:"
echo ""
echo "kubectl exec -it \$(kubectl get pods -n $NAMESPACE -l app=redis-enterprise -o jsonpath='{.items[0].metadata.name}') -c redis-enterprise-node -n $NAMESPACE -- cat /etc/opt/redislabs/proxy_cert.pem > ca.crt"
echo ""
echo "You can also use the following command to test the connection without redis-cli:"
echo ""
echo "openssl s_client -connect $DB_HOST:$DB_PORT -servername $SNI_HOST -CAfile ca.crt"
echo ""
echo "Once connected, type 'PING' and press Enter. You should receive '+PONG' in response."
echo ""

# Provide a direct test command if redis-cli is available
echo "Would you like to test the connection now? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    # Get the CA certificate
    echo "Retrieving CA certificate..."
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "app=redis-enterprise" -o jsonpath='{.items[0].metadata.name}')
    if [ -z "$POD_NAME" ]; then
        echo "Error: Could not find any Redis Enterprise pods."
        exit 1
    fi
    
    echo "Using Redis Enterprise pod: $POD_NAME"
    kubectl exec -it "$POD_NAME" -c redis-enterprise-node -n "$NAMESPACE" -- cat /etc/opt/redislabs/proxy_cert.pem > ca.crt
    
    echo "CA certificate saved to ca.crt"
    echo ""
    echo "Connecting to Redis Enterprise Database..."
    echo "Command: redis-cli -h $DB_HOST -p $DB_PORT --tls --sni $SNI_HOST --cacert ca.crt -a '$PASSWORD'"
    echo ""
    
    # Connect using redis-cli
    redis-cli -h "$DB_HOST" -p "$DB_PORT" --tls --sni "$SNI_HOST" --cacert ca.crt -a "$PASSWORD"
    
    # Clean up
    echo ""
    echo "Cleaning up..."
    rm -f ca.crt
    echo "Done."
fi
