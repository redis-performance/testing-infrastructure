#!/bin/bash
#
# get-proxy-info.sh - Extract proxy information from Redis Enterprise Cluster REST API
#
# This script retrieves proxy information from the Redis Enterprise Cluster REST API
# and displays it in a readable format.
#

# Configuration
NAMESPACE="rec-large-scale"
CLUSTER_NAME="rec-large-scale-5nodes"
API_PORT="9443"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== Redis Enterprise Cluster Proxy Information ===${NC}"
echo ""

# Check if the Redis Enterprise Cluster is ready
echo -e "${BOLD}Step 1: Checking if the Redis Enterprise Cluster is ready...${NC}"
CLUSTER_STATUS=$(kubectl get rec $CLUSTER_NAME -n $NAMESPACE -o jsonpath='{.status.state}' 2>/dev/null)

if [ -z "$CLUSTER_STATUS" ]; then
    echo -e "${RED}Error: Redis Enterprise Cluster not found or not accessible.${NC}"
    echo "Please make sure the Redis Enterprise Cluster is deployed and you have the correct permissions."
    exit 1
fi

if [ "$CLUSTER_STATUS" != "Running" ]; then
    echo -e "${YELLOW}Warning: Redis Enterprise Cluster is not yet active (current state: $CLUSTER_STATUS).${NC}"
    echo "Please wait for the cluster to become active before running this script."
    exit 1
fi

echo "Redis Enterprise Cluster is active."

# Get cluster credentials
echo ""
echo -e "${BOLD}Step 2: Getting cluster credentials...${NC}"
USERNAME=$(kubectl get secret $CLUSTER_NAME -n $NAMESPACE -o jsonpath='{.data.username}' 2>/dev/null | base64 --decode)
PASSWORD=$(kubectl get secret $CLUSTER_NAME -n $NAMESPACE -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode)

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo -e "${RED}Error: Failed to get cluster credentials.${NC}"
    echo "Please make sure the Redis Enterprise Cluster is deployed and running."
    exit 1
fi

echo "Cluster credentials retrieved."

# Set up port forwarding to the cluster API
echo ""
echo -e "${BOLD}Step 3: Setting up port forwarding to the cluster API...${NC}"
echo "Starting port forwarding in the background..."
kubectl port-forward service/$CLUSTER_NAME -n $NAMESPACE $API_PORT:$API_PORT > /dev/null 2>&1 &
PORT_FORWARD_PID=$!

# Ensure port forwarding is killed when the script exits
trap "kill $PORT_FORWARD_PID 2>/dev/null" EXIT

# Wait for port forwarding to be established
echo "Waiting for port forwarding to be established..."
sleep 3

# Test the connection
echo "Testing connection to the cluster API..."
if ! curl -s -k https://localhost:$API_PORT/v1/cluster > /dev/null; then
    echo -e "${RED}Error: Failed to connect to the cluster API.${NC}"
    echo "Please make sure the Redis Enterprise Cluster is deployed and running."
    exit 1
fi

echo "Connection to the cluster API established."

# Get proxy information
echo ""
echo -e "${BOLD}Step 4: Getting proxy information...${NC}"
echo "Retrieving proxy information from the REST API..."

# Get all proxies
PROXIES=$(curl -s -k -u "$USERNAME:$PASSWORD" https://localhost:$API_PORT/v1/proxies)

# Check if the request was successful
if [[ $PROXIES == *"error"* ]]; then
    echo -e "${RED}Error: Failed to get proxy information.${NC}"
    echo "Response: $PROXIES"
    exit 1
fi

# Format and display proxy information
echo ""
echo -e "${BOLD}Proxy Information:${NC}"
echo "$PROXIES" | python3 -m json.tool

# Get detailed information for each proxy
echo ""
echo -e "${BOLD}Step 5: Getting detailed information for each proxy...${NC}"

# Extract proxy IDs
PROXY_IDS=$(echo "$PROXIES" | python3 -c "import sys, json; print(' '.join([str(p['uid']) for p in json.load(sys.stdin)]))")

for PROXY_ID in $PROXY_IDS; do
    echo ""
    echo -e "${BOLD}Detailed information for proxy $PROXY_ID:${NC}"

    # Get detailed proxy information
    PROXY_DETAILS=$(curl -s -k -u "$USERNAME:$PASSWORD" https://localhost:$API_PORT/v1/proxies/$PROXY_ID)

    # Format and display proxy details
    echo "$PROXY_DETAILS" | python3 -m json.tool
done

echo ""
echo -e "${BOLD}=== Proxy Information Retrieval Complete ===${NC}"
echo ""
echo "For more information about the Redis Enterprise Cluster REST API, visit:"
echo "https://redis.io/docs/latest/operate/rs/references/rest-api/objects/proxy/"
