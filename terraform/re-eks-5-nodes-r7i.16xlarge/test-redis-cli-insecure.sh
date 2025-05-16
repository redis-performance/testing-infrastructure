#!/bin/bash
#
# test-redis-cli-insecure.sh - Test connection to Redis Enterprise Database using redis-cli with insecure TLS
#
# This script tests the connection to the Redis Enterprise Database using redis-cli with the --tls --insecure options.
# It retrieves the database port, hostname, and password, and attempts to connect to the database.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
USE_LB_HOSTNAME=true  # Set to false to use the Ingress hostname (primary-db.example.com)

echo "Testing connection to Redis Enterprise Database '$DB_NAME' using redis-cli with insecure TLS..."

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
    PASSWORD=""
    AUTH_OPTION=""
else
    AUTH_OPTION="-a $PASSWORD"
fi

echo ""
echo "Connecting to Redis Enterprise Database..."
echo "Command: redis-cli -h $DB_HOST -p $DB_PORT --tls --insecure --sni $SNI_HOST $AUTH_OPTION"
echo ""
echo "First, let's check if we can reach the host and port using telnet..."
echo "Command: timeout 5 telnet $DB_HOST $DB_PORT"
echo ""

# Try to connect using telnet with a timeout
timeout 5 telnet "$DB_HOST" "$DB_PORT" 2>&1 || echo "Telnet connection failed or timed out."

echo ""
echo "Now, let's try to connect using redis-cli with a timeout..."
echo "Command: timeout 10 redis-cli -h $DB_HOST -p $DB_PORT --tls --insecure --sni $SNI_HOST $AUTH_OPTION PING"
echo ""

# Try a simple PING command with a timeout
timeout 10 redis-cli -h "$DB_HOST" -p "$DB_PORT" --tls --insecure --sni "$SNI_HOST" $AUTH_OPTION PING || echo "Redis connection failed or timed out."

echo ""
echo "If the connection is hanging, there might be connectivity issues or firewall rules blocking the connection."
echo "Let's try a different approach - connecting to the database from inside a Redis Enterprise pod."
echo ""

# Get a Redis Enterprise pod name
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "app=redis-enterprise" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD_NAME" ]; then
    echo "Using Redis Enterprise pod: $POD_NAME"
    echo "Command: kubectl exec -it $POD_NAME -c redis-enterprise-node -n $NAMESPACE -- redis-cli -h redis-$DB_PORT.$NAMESPACE.svc.cluster.local -p $DB_PORT $AUTH_OPTION"
    echo ""
    echo "Would you like to try connecting from inside the pod? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        kubectl exec -it "$POD_NAME" -c redis-enterprise-node -n "$NAMESPACE" -- redis-cli -h "redis-$DB_PORT.$NAMESPACE.svc.cluster.local" -p "$DB_PORT" $AUTH_OPTION
    fi
else
    echo "Could not find any Redis Enterprise pods. Make sure you have the correct permissions."
fi

echo ""
echo "If you want to try connecting using the interactive redis-cli, run:"
echo "redis-cli -h $DB_HOST -p $DB_PORT --tls --insecure --sni $SNI_HOST $AUTH_OPTION"
echo ""
echo "Once connected, you can run Redis commands like:"
echo "PING"
echo "SET key value"
echo "GET key"
