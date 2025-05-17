#!/bin/bash
#
# test-ssl-passthrough.sh - Test SSL passthrough connection to Redis Enterprise Database
#
# This script tests the SSL passthrough connection to a Redis Enterprise Database using redis-cli
# with the --tls and --insecure options.
#

# Configuration
LB_HOSTNAME="a245ddcf13c764d7aada41f71a8bbcad-220634774.us-east-2.elb.amazonaws.com"
DB_NAME="primary"
PASSWORD="fEyYdaqU"  # Correct password retrieved from Kubernetes secret

echo "=== Testing SSL Passthrough Connection to Redis Enterprise Database ==="
echo ""
echo "LoadBalancer hostname: $LB_HOSTNAME"
echo "Database name: $DB_NAME"
echo "SNI hostname: $DB_NAME.$LB_HOSTNAME"
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
echo "Command: redis-cli -h $LB_HOSTNAME -p 443 --tls --insecure --sni $DB_NAME.$LB_HOSTNAME -a $PASSWORD"
echo ""
echo "Executing command..."
redis-cli -h "$LB_HOSTNAME" -p 443 --tls --insecure --sni "$DB_NAME.$LB_HOSTNAME" -a "$PASSWORD" PING

# Check the result
if [ $? -eq 0 ]; then
    echo ""
    echo "Connection successful!"
    echo ""
    echo "You can now use redis-cli to interact with the database:"
    echo "redis-cli -h $LB_HOSTNAME -p 443 --tls --insecure --sni $DB_NAME.$LB_HOSTNAME -a $PASSWORD"
else
    echo ""
    echo "Connection failed."
    echo ""
    echo "Let's try to diagnose the issue:"
    echo ""
    
    # Check if the LoadBalancer hostname is resolvable
    echo "1. Checking if the LoadBalancer hostname is resolvable..."
    if nslookup "$LB_HOSTNAME" &>/dev/null; then
        echo "LoadBalancer hostname is resolvable."
    else
        echo "Error: LoadBalancer hostname is not resolvable."
        echo "Please check your DNS configuration."
        exit 1
    fi
    
    # Check if the port is open
    echo ""
    echo "2. Checking if the port is open..."
    if nc -z -w 5 "$LB_HOSTNAME" 443 &>/dev/null; then
        echo "Port 443 is open on $LB_HOSTNAME."
    else
        echo "Error: Port 443 is not open on $LB_HOSTNAME."
        echo "Please check your firewall and security group settings."
        exit 1
    fi
    
    # Check if TLS is working
    echo ""
    echo "3. Checking if TLS is working..."
    if openssl s_client -connect "$LB_HOSTNAME:443" -servername "$DB_NAME.$LB_HOSTNAME" -quiet </dev/null &>/dev/null; then
        echo "TLS connection successful."
    else
        echo "Error: TLS connection failed."
        echo "Please check your TLS configuration."
        exit 1
    fi
    
    # Check if SNI is working
    echo ""
    echo "4. Checking if SNI is working..."
    if openssl s_client -connect "$LB_HOSTNAME:443" -servername "$DB_NAME.$LB_HOSTNAME" -quiet </dev/null 2>&1 | grep -q "Server name"; then
        echo "SNI is working."
    else
        echo "Warning: SNI might not be working correctly."
        echo "Please check your HAProxy Ingress configuration."
    fi
    
    # Check if the password is correct
    echo ""
    echo "5. Checking if the password is correct..."
    echo "Please verify that the password '$PASSWORD' is correct."
    echo "You can get the correct password using:"
    echo "kubectl get secret redb-$DB_NAME -n rec-large-scale -o jsonpath=\"{.data.password}\" | base64 --decode"
    
    echo ""
    echo "For more detailed troubleshooting, check the HAProxy Ingress logs:"
    echo "kubectl logs -n rec-large-scale -l app.kubernetes.io/name=haproxy-ingress"
fi
