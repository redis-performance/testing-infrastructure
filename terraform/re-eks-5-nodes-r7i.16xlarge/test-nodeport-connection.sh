#!/bin/bash
#
# test-nodeport-connection.sh - Test external connection to Redis Enterprise Database using NodePort
#
# This script tests the external connection to a Redis Enterprise Database using redis-cli
# with the --tls and --insecure options, connecting through a NodePort.
#

# Configuration
NODE_IP="18.223.203.147"  # Use the external IP of one of the nodes
NODE_PORT="30793"
DB_NAME="primary"
PASSWORD="fEyYdaqU"  # Correct password retrieved from Kubernetes secret

echo "=== Testing NodePort Connection to Redis Enterprise Database ==="
echo ""
echo "Node IP: $NODE_IP"
echo "Node Port: $NODE_PORT"
echo "Database name: $DB_NAME"
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
echo "Command: redis-cli -h $NODE_IP -p $NODE_PORT --tls --insecure -a $PASSWORD"
echo ""
echo "Executing command..."
redis-cli -h "$NODE_IP" -p "$NODE_PORT" --tls --insecure -a "$PASSWORD" PING

# Check the result
if [ $? -eq 0 ]; then
    echo ""
    echo "Connection successful!"
    echo ""
    echo "You can now use redis-cli to interact with the database:"
    echo "redis-cli -h $NODE_IP -p $NODE_PORT --tls --insecure -a $PASSWORD"
else
    echo ""
    echo "Connection failed."
    echo ""
    echo "Let's try to diagnose the issue:"
    echo ""

    # Check if the Node IP is reachable
    echo "1. Checking if the Node IP is reachable..."
    if ping -c 1 "$NODE_IP" &>/dev/null; then
        echo "Node IP is reachable."
    else
        echo "Error: Node IP is not reachable."
        echo "Please check your network configuration."
        exit 1
    fi

    # Check if the port is open
    echo ""
    echo "2. Checking if the port is open..."
    if nc -z -w 5 "$NODE_IP" "$NODE_PORT" &>/dev/null; then
        echo "Port $NODE_PORT is open on $NODE_IP."
    else
        echo "Error: Port $NODE_PORT is not open on $NODE_IP."
        echo "Please check your firewall and security group settings."
        exit 1
    fi

    # Check if TLS is working
    echo ""
    echo "3. Checking if TLS is working..."
    if openssl s_client -connect "$NODE_IP:$NODE_PORT" -quiet </dev/null &>/dev/null; then
        echo "TLS connection successful."
    else
        echo "Error: TLS connection failed."
        echo "Please check your TLS configuration."
        exit 1
    fi

    # Check if the password is correct
    echo ""
    echo "4. Checking if the password is correct..."
    echo "Please verify that the password '$PASSWORD' is correct."
    echo "You can get the correct password using:"
    echo "kubectl get secret redb-$DB_NAME -n rec-large-scale -o jsonpath=\"{.data.password}\" | base64 --decode"

    echo ""
    echo "For more detailed troubleshooting, check the Redis Enterprise Database logs:"
    echo "kubectl logs -n rec-large-scale -l redis.io/database=$DB_NAME"
fi
