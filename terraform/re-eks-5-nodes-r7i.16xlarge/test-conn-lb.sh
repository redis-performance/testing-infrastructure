#!/bin/bash
#
# test-conn-lb.sh - Test connection to Redis Enterprise Database using LoadBalancer hostname
#
# This script tests the connection to the Redis Enterprise Database using the LoadBalancer hostname.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
DB_NAME="primary"
LB_HOSTNAME=$(cat haproxy_hostname.txt)
DB_HOST="$LB_HOSTNAME"
SNI_HOST="$DB_NAME.$LB_HOSTNAME"

echo "Testing connection to Redis Enterprise Database '$DB_NAME'..."
echo "Using LoadBalancer hostname: $DB_HOST"
echo "Using SNI hostname: $SNI_HOST"
echo ""
echo "To test the connection, run the following command:"
echo ""
echo "openssl s_client -connect $DB_HOST:443 -servername $SNI_HOST"
echo ""
echo "Once connected, type 'PING' and press Enter. You should receive '+PONG' in response."
echo ""
echo "Note: The LoadBalancer hostname is used for the connection, but the SNI hostname"
echo "is used to route the request to the correct backend service."
