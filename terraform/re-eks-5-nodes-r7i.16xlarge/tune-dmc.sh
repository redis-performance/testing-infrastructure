#!/bin/bash
#
# tune-dmc.sh - Tune the Proxy (DMC) for Redis Enterprise Cluster
#
# This script updates the DMC configuration to change threads from 3 to 16 and max_threads from 16 to 24.
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

echo -e "${BOLD}=== Tuning Redis Enterprise Cluster Proxy Configuration ===${NC}"
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

# Get current proxy configuration
echo ""
echo -e "${BOLD}Step 4: Getting current proxy configuration...${NC}"
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

# Extract proxy IDs
PROXY_IDS=$(echo "$PROXIES" | python3 -c "import sys, json; print(' '.join([str(p['uid']) for p in json.load(sys.stdin)]))")

echo ""
echo -e "${BOLD}Found proxies with IDs: $PROXY_IDS${NC}"
echo ""
echo -e "${BOLD}Current configuration for all proxies:${NC}"
echo "$PROXIES" | python3 -m json.tool

# Create JSON payload for updating proxy configuration
echo ""
echo -e "${BOLD}Step 5: Creating JSON payload for updating proxy configuration...${NC}"

# Create a temporary file for the JSON payload
PAYLOAD_FILE=$(mktemp)

cat > $PAYLOAD_FILE << EOF
{
  "allow_restart": true,
  "proxy": {
    "threads": 16,
    "max_threads": 24
  }
}
EOF

echo "JSON payload created:"
cat $PAYLOAD_FILE | python3 -m json.tool

# Update all proxies configuration
echo ""
echo -e "${BOLD}Step 6: Updating configuration for ALL proxies...${NC}"
echo "Sending update request to the REST API..."

# Use the /v1/proxies endpoint (without a specific ID) to update all proxies at once
UPDATE_RESPONSE=$(curl -s -k -u "$USERNAME:$PASSWORD" -X PUT -H "Content-Type: application/json" -d @$PAYLOAD_FILE https://localhost:$API_PORT/v1/proxies)

# Remove the temporary file
rm $PAYLOAD_FILE

# Check if the update was successful
if [[ $UPDATE_RESPONSE == *"error"* ]]; then
    echo -e "${RED}Error: Failed to update proxy configuration.${NC}"
    echo "Response: $UPDATE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}Proxy configuration updated successfully.${NC}"

# Get updated proxy configuration for all proxies
echo ""
echo -e "${BOLD}Step 7: Getting updated proxy configuration for all proxies...${NC}"
echo "Retrieving updated proxy configuration from the REST API..."

UPDATED_PROXIES=$(curl -s -k -u "$USERNAME:$PASSWORD" https://localhost:$API_PORT/v1/proxies)

# Display updated proxy configuration
echo ""
echo -e "${BOLD}Updated Proxy Configuration for all proxies:${NC}"
echo "$UPDATED_PROXIES" | python3 -m json.tool

echo ""
echo -e "${BOLD}=== Proxy Configuration Update Complete ===${NC}"
echo ""
echo "The proxy configuration has been updated with the following changes:"
echo "- threads: 3 -> 16"
echo "- max_threads: 16 -> 24"
echo ""
echo "For more information about the Redis Enterprise Cluster REST API, visit:"
echo "https://redis.io/docs/latest/operate/rs/references/rest-api/requests/proxies/"
