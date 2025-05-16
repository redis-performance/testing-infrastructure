#!/bin/bash
#
# test-redis-port-12000.sh - Test connection to Redis Enterprise Database on port 12000
#
# This script tests the connection to a Redis Enterprise Database through the TCP proxy
# on port 12000.
#

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
PROXY_PORT="12000"

echo "=== Testing Connection to Redis Enterprise Database on Port 12000 ==="
echo ""

# Get the LoadBalancer hostname for the TCP proxy
echo "Step 1: Getting the LoadBalancer hostname for the TCP proxy..."
LB_HOSTNAME=$(kubectl get service redis-tcp-proxy -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -z "$LB_HOSTNAME" ]; then
    echo "Error: LoadBalancer hostname not available. Please make sure the TCP proxy is running."
    exit 1
fi
echo "LoadBalancer hostname: $LB_HOSTNAME"

# Get the database password
echo ""
echo "Step 2: Getting the database password..."
PASSWORD=$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode 2>/dev/null)
if [ -z "$PASSWORD" ]; then
    echo "Error: Could not retrieve the database password."
    exit 1
fi
echo "Database password retrieved."

# Check if redis-cli is installed
echo ""
echo "Step 3: Checking if redis-cli is installed..."
if ! command -v redis-cli &> /dev/null; then
    echo "Error: redis-cli is not installed."
    echo "Please install redis-cli using your package manager."
    echo "For example: sudo apt-get install redis-tools"
    exit 1
fi
echo "redis-cli is installed."

# Test connection using redis-cli
echo ""
echo "Step 4: Testing connection using redis-cli..."
echo "Command: redis-cli -h $LB_HOSTNAME -p $PROXY_PORT -a $PASSWORD PING"
echo ""
echo "Executing command..."
RESULT=$(redis-cli -h "$LB_HOSTNAME" -p "$PROXY_PORT" -a "$PASSWORD" PING)

# Check the result
if [ "$RESULT" = "PONG" ]; then
    echo ""
    echo "Connection successful!"
    echo ""
    echo "You can now use redis-cli to interact with the database:"
    echo "redis-cli -h $LB_HOSTNAME -p $PROXY_PORT -a $PASSWORD"
else
    echo ""
    echo "Connection failed."
    echo ""
    echo "Let's try to diagnose the issue:"
    echo ""
    
    # Check if the port is open
    echo "1. Checking if the port is open..."
    nc -zv "$LB_HOSTNAME" "$PROXY_PORT" 2>&1 || echo "Netcat connection failed or timed out."
    
    # Check if the TCP proxy pod is running
    echo ""
    echo "2. Checking if the TCP proxy pod is running..."
    kubectl get pods -n $NAMESPACE -l app=redis-tcp-proxy
    
    # Check the TCP proxy pod logs
    echo ""
    echo "3. Checking the TCP proxy pod logs..."
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=redis-tcp-proxy -o jsonpath='{.items[0].metadata.name}')
    kubectl logs "$POD_NAME" -n $NAMESPACE
    
    echo ""
    echo "4. For more detailed troubleshooting, run the diagnose-connection-timeout.sh script."
fi
