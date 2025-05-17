#!/bin/bash
#
# test-portforward-connection.sh - Test connection to Redis Enterprise Database using port forwarding
#
# This script tests the connection to a Redis Enterprise Database using redis-cli
# with the --tls and --insecure options, connecting through port forwarding.
#

# Configuration
DB_NAME="primary"
LOCAL_PORT="11793"
PASSWORD="VK7wvBPC"  # Replace with your actual password if different

echo "=== Testing Port Forward Connection to Redis Enterprise Database ==="
echo ""
echo "Database name: $DB_NAME"
echo "Local port: $LOCAL_PORT"
echo ""

# Check if redis-cli is installed
if ! command -v redis-cli &> /dev/null; then
    echo "Error: redis-cli is not installed."
    echo "Please install redis-cli using your package manager."
    echo "For example: sudo apt-get install redis-tools"
    exit 1
fi

# Start port forwarding in the background
echo "Starting port forwarding..."
kubectl port-forward svc/$DB_NAME -n rec-large-scale $LOCAL_PORT:$LOCAL_PORT > /dev/null 2>&1 &
PORT_FORWARD_PID=$!

# Ensure port forwarding is killed when the script exits
trap "kill $PORT_FORWARD_PID 2>/dev/null" EXIT

# Wait for port forwarding to be established
echo "Waiting for port forwarding to be established..."
sleep 3

# Test connection using redis-cli
echo "Testing connection using redis-cli..."
echo "Command: redis-cli -p $LOCAL_PORT --tls --insecure -a $PASSWORD"
echo ""
echo "Executing command..."
redis-cli -p "$LOCAL_PORT" --tls --insecure -a "$PASSWORD" PING

# Check the result
if [ $? -eq 0 ]; then
    echo ""
    echo "Connection successful!"
    echo ""
    echo "You can now use redis-cli to interact with the database:"
    echo "redis-cli -p $LOCAL_PORT --tls --insecure -a $PASSWORD"
else
    echo ""
    echo "Connection failed."
    echo ""
    echo "Let's try to diagnose the issue:"
    echo ""
    
    # Check if port forwarding is working
    echo "1. Checking if port forwarding is working..."
    if nc -z -w 5 localhost "$LOCAL_PORT" &>/dev/null; then
        echo "Port forwarding is working."
    else
        echo "Error: Port forwarding is not working."
        echo "Please check the port forwarding logs:"
        echo "kubectl port-forward svc/$DB_NAME -n rec-large-scale $LOCAL_PORT:$LOCAL_PORT"
        exit 1
    fi
    
    # Check if TLS is working
    echo ""
    echo "2. Checking if TLS is working..."
    if openssl s_client -connect localhost:"$LOCAL_PORT" -quiet </dev/null &>/dev/null; then
        echo "TLS connection successful."
    else
        echo "Error: TLS connection failed."
        echo "Please check your TLS configuration."
        exit 1
    fi
    
    # Check if the password is correct
    echo ""
    echo "3. Checking if the password is correct..."
    echo "Please verify that the password '$PASSWORD' is correct."
    echo "You can get the correct password using:"
    echo "kubectl get secret redb-$DB_NAME -n rec-large-scale -o jsonpath=\"{.data.password}\" | base64 --decode"
    
    echo ""
    echo "For more detailed troubleshooting, check the Redis Enterprise Database logs:"
    echo "kubectl logs -n rec-large-scale -l redis.io/bdb-1=1"
fi
