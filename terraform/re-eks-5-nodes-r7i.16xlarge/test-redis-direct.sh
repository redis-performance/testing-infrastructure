#!/bin/bash
#
# test-redis-direct.sh - Test connection to Redis Enterprise Database using direct TCP port
#
# This script tests the connection to a Redis Enterprise Database using redis-cli
# with the --tls and --insecure options, connecting directly to port 11793.
#

# Configuration
LB_HOSTNAME="a774cbc5b6f0e4c3c8591b1f5bfe945e-398267775.us-east-2.elb.amazonaws.com"
DB_NAME="primary"
DB_PORT="11793"
PASSWORD="VK7wvBPC"  # Replace with your actual password if different

echo "=== Testing Direct TCP Connection to Redis Enterprise Database ==="
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
echo "Command: redis-cli -h $LB_HOSTNAME -p $DB_PORT --tls --insecure -a $PASSWORD PING"
echo ""
echo "Executing command..."
redis-cli -h "$LB_HOSTNAME" -p "$DB_PORT" --tls --insecure -a "$PASSWORD" PING

# Check the result
if [ $? -eq 0 ]; then
    echo ""
    echo "Connection successful!"
    echo ""
    echo "You can now use redis-cli to interact with the database:"
    echo "redis-cli -h $LB_HOSTNAME -p $DB_PORT --tls --insecure -a $PASSWORD"
else
    echo ""
    echo "Connection failed."
    echo ""
    echo "Let's try to diagnose the issue:"
    echo ""
    
    # Check if the port is open
    echo "1. Checking if the port is open..."
    nc -zv "$LB_HOSTNAME" "$DB_PORT" 2>&1 || echo "Netcat connection failed or timed out."
    
    # Check if TLS is working
    echo ""
    echo "2. Checking if TLS is working..."
    echo "QUIT" | openssl s_client -connect "$LB_HOSTNAME:$DB_PORT" -quiet 2>&1 || echo "OpenSSL connection failed."
    
    echo ""
    echo "3. For more detailed troubleshooting, run the diagnose-connection-timeout.sh script."
fi
