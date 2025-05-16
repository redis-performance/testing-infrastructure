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
echo "Once connected, you can run Redis commands like:"
echo "PING"
echo "SET key value"
echo "GET key"
echo ""

# Connect using redis-cli
redis-cli -h "$DB_HOST" -p "$DB_PORT" --tls --insecure --sni "$SNI_HOST" $AUTH_OPTION
