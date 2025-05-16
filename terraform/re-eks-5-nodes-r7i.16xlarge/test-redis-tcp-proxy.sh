#!/bin/bash
#
# test-redis-tcp-proxy.sh - Test connection to Redis Enterprise Database through TCP proxy
#
# This script tests the connection to a Redis Enterprise Database through the TCP proxy
# using redis-cli with the --tls and --insecure options.
#

# Configuration
LB_HOSTNAME="a3e7e098f724d48729e5205a0408ba0a-1707159551.us-east-2.elb.amazonaws.com"
DB_NAME="primary"
DB_PORT="6379"
PASSWORD="VK7wvBPC"  # Replace with your actual password if different

echo "=== Testing Connection to Redis Enterprise Database Through TCP Proxy ==="
echo ""
echo "LoadBalancer hostname: $LB_HOSTNAME"
echo "Database name: $DB_NAME"
echo "Database port: $DB_PORT"
echo ""

# Check if redis-cli is installed
if ! command -v redis-cli &> /dev/null; then
    echo "Error: redis-cli is not installed."
    echo "Please install redis-cli using your package manager."
    echo "For example: sudo apt-get install redis-tools"
    exit 1
fi

# Test connection using redis-cli
echo "Testing connection using redis-cli..."
echo "Command: redis-cli -h $LB_HOSTNAME -p $DB_PORT -a $PASSWORD PING"
echo ""
echo "Executing command..."
redis-cli -h "$LB_HOSTNAME" -p "$DB_PORT" -a "$PASSWORD" PING

# Check the result
if [ $? -eq 0 ]; then
    echo ""
    echo "Connection successful!"
    echo ""
    echo "You can now use redis-cli to interact with the database:"
    echo "redis-cli -h $LB_HOSTNAME -p $DB_PORT -a $PASSWORD"
else
    echo ""
    echo "Connection failed."
    echo ""
    echo "Let's try with TLS..."
    echo "Command: redis-cli -h $LB_HOSTNAME -p $DB_PORT --tls --insecure -a $PASSWORD PING"
    echo ""
    echo "Executing command..."
    redis-cli -h "$LB_HOSTNAME" -p "$DB_PORT" --tls --insecure -a "$PASSWORD" PING

    if [ $? -eq 0 ]; then
        echo ""
        echo "Connection successful with TLS!"
        echo ""
        echo "You can now use redis-cli to interact with the database:"
        echo "redis-cli -h $LB_HOSTNAME -p $DB_PORT --tls --insecure -a $PASSWORD"
    else
        echo ""
        echo "Connection failed with TLS."
        echo ""
        echo "Let's try to diagnose the issue:"
        echo ""

        # Check if the port is open
        echo "1. Checking if the port is open..."
        nc -zv "$LB_HOSTNAME" "$DB_PORT" 2>&1 || echo "Netcat connection failed or timed out."

        # Check if the TCP proxy pod is running
        echo ""
        echo "2. Checking if the TCP proxy pod is running..."
        kubectl get pods -n rec-large-scale -l app=redis-tcp-proxy

        # Check the TCP proxy pod logs
        echo ""
        echo "3. Checking the TCP proxy pod logs..."
        POD_NAME=$(kubectl get pods -n rec-large-scale -l app=redis-tcp-proxy -o jsonpath='{.items[0].metadata.name}')
        kubectl logs "$POD_NAME" -n rec-large-scale

        echo ""
        echo "4. For more detailed troubleshooting, run the diagnose-connection-timeout.sh script."
    fi
fi
