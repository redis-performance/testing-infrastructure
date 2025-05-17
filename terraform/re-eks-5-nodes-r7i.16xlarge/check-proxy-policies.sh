#!/bin/bash
#
# check-proxy-policies.sh - Check proxy policies in Redis Enterprise Cluster
#
# This script retrieves and analyzes proxy policies in Redis Enterprise Cluster
# to ensure they are correctly configured.
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

echo -e "${BOLD}=== Redis Enterprise Cluster Proxy Policies Analysis ===${NC}"
echo ""

# Check if the Redis Enterprise Cluster is ready
echo -e "${BOLD}Step 1: Checking if the Redis Enterprise Cluster is ready...${NC}"
CLUSTER_STATUS=$(kubectl get rec $CLUSTER_NAME -n $NAMESPACE -o jsonpath='{.status.state}' 2>/dev/null)

if [ -z "$CLUSTER_STATUS" ]; then
    echo -e "${RED}Error: Redis Enterprise Cluster not found or not accessible.${NC}"
    echo "Please make sure the Redis Enterprise Cluster is deployed and you have the correct permissions."
    exit 1
fi

if [ "$CLUSTER_STATUS" != "active" ]; then
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
echo -e "${BOLD}Step 2: Setting up port forwarding to the cluster API...${NC}"
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

# Get proxy policies
echo ""
echo -e "${BOLD}Step 3: Getting proxy policies...${NC}"
echo "Retrieving proxy policies from the REST API..."

# Get all proxy policies
PROXY_POLICIES=$(curl -s -k -u "$USERNAME:$PASSWORD" https://localhost:$API_PORT/v1/proxy_policies)

# Check if the request was successful
if [[ $PROXY_POLICIES == *"error"* ]]; then
    echo -e "${RED}Error: Failed to get proxy policies.${NC}"
    echo "Response: $PROXY_POLICIES"
    exit 1
fi

# Format and display proxy policies
echo ""
echo -e "${BOLD}Proxy Policies:${NC}"
POLICIES_INFO=$(echo "$PROXY_POLICIES" | python3 -c "
import sys, json
policies = json.load(sys.stdin)
for policy in policies:
    print(f\"Policy: {policy.get('name', 'N/A')} (ID: {policy.get('uid', 'N/A')}):\")
    print(f\"  Type: {policy.get('type', 'N/A')}\")
    print(f\"  Active: {'Yes' if policy.get('active', False) else 'No'}\")

    rules = policy.get('rules', [])
    if rules:
        print(\"  Rules:\")
        for rule in rules:
            print(f\"    - {rule.get('name', 'N/A')}: {rule.get('value', 'N/A')}\")

    print()
")

echo "$POLICIES_INFO"

# Get databases with their proxy policies
echo ""
echo -e "${BOLD}Step 4: Getting databases with their proxy policies...${NC}"
echo "Retrieving database information from the REST API..."

# Get all databases
DATABASES=$(curl -s -k -u "$USERNAME:$PASSWORD" https://localhost:$API_PORT/v1/bdbs)

# Check if the request was successful
if [[ $DATABASES == *"error"* ]]; then
    echo -e "${RED}Error: Failed to get database information.${NC}"
    echo "Response: $DATABASES"
    exit 1
fi

# Format and display database proxy policies
echo ""
echo -e "${BOLD}Database Proxy Policies:${NC}"
DB_POLICIES=$(echo "$DATABASES" | python3 -c "
import sys, json
databases = json.load(sys.stdin)
for db in databases:
    print(f\"Database: {db.get('name', 'N/A')} (ID: {db.get('uid', 'N/A')}):\")
    print(f\"  Proxy Policy: {db.get('proxy_policy', 'N/A')}\")
    print(f\"  SSL: {'Enabled' if db.get('ssl', False) else 'Disabled'}\")
    print(f\"  TLS Mode: {db.get('tls_mode', 'N/A')}\")
    print()
")

echo "$DB_POLICIES"

# Analyze proxy policies
echo ""
echo -e "${BOLD}Step 5: Analyzing proxy policies...${NC}"
echo "Checking if proxy policies are correctly configured..."

# Extract policy information
POLICY_INFO=$(echo "$PROXY_POLICIES" | python3 -c "
import sys, json
policies = json.load(sys.stdin)
for policy in policies:
    print(f\"{policy.get('uid', 'N/A')}:{policy.get('name', 'N/A')}:{policy.get('type', 'N/A')}:{policy.get('active', False)}\")
")

# Extract database information
DB_INFO=$(echo "$DATABASES" | python3 -c "
import sys, json
databases = json.load(sys.stdin)
for db in databases:
    print(f\"{db.get('uid', 'N/A')}:{db.get('name', 'N/A')}:{db.get('proxy_policy', 'N/A')}:{db.get('ssl', False)}:{db.get('tls_mode', 'N/A')}\")
")

# Check if each database has a valid proxy policy
echo ""
echo -e "${BOLD}Database Proxy Policy Analysis:${NC}"
for DB in $DB_INFO; do
    DB_ID=$(echo $DB | cut -d':' -f1)
    DB_NAME=$(echo $DB | cut -d':' -f2)
    DB_POLICY=$(echo $DB | cut -d':' -f3)
    DB_SSL=$(echo $DB | cut -d':' -f4)
    DB_TLS_MODE=$(echo $DB | cut -d':' -f5)

    echo "Checking database: $DB_NAME (ID: $DB_ID)"

    # Check if the database has a proxy policy
    if [ "$DB_POLICY" == "N/A" ] || [ -z "$DB_POLICY" ]; then
        echo -e "${RED}✗ Database $DB_NAME does not have a proxy policy.${NC}"
        continue
    fi

    # Check if the proxy policy exists
    POLICY_EXISTS=false
    POLICY_TYPE=""
    POLICY_ACTIVE=false

    for POLICY in $POLICY_INFO; do
        POLICY_ID=$(echo $POLICY | cut -d':' -f1)
        POLICY_NAME=$(echo $POLICY | cut -d':' -f2)
        POLICY_TYPE=$(echo $POLICY | cut -d':' -f3)
        POLICY_ACTIVE=$(echo $POLICY | cut -d':' -f4)

        if [ "$POLICY_ID" == "$DB_POLICY" ]; then
            POLICY_EXISTS=true
            break
        fi
    done

    if [ "$POLICY_EXISTS" == "true" ]; then
        echo -e "${GREEN}✓ Database $DB_NAME has a valid proxy policy: $POLICY_NAME (Type: $POLICY_TYPE).${NC}"

        # Check if the policy is active
        if [ "$POLICY_ACTIVE" == "True" ]; then
            echo -e "${GREEN}✓ Proxy policy is active.${NC}"
        else
            echo -e "${RED}✗ Proxy policy is not active.${NC}"
        fi

        # Check SSL configuration
        if [ "$DB_SSL" == "True" ]; then
            echo -e "${GREEN}✓ Database has SSL enabled.${NC}"

            # Check TLS mode
            if [ "$DB_TLS_MODE" == "enabled" ]; then
                echo -e "${GREEN}✓ TLS mode is enabled.${NC}"
            else
                echo -e "${YELLOW}⚠ TLS mode is $DB_TLS_MODE, but SSL is enabled.${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ Database does not have SSL enabled.${NC}"
        fi
    else
        echo -e "${RED}✗ Database $DB_NAME has an invalid proxy policy ID: $DB_POLICY.${NC}"
    fi

    echo ""
done

echo ""
echo -e "${BOLD}=== Proxy Policies Analysis Complete ===${NC}"
echo ""
echo "For more information about Redis Enterprise Cluster proxy policies, visit:"
echo "https://redis.io/docs/latest/operate/rs/references/rest-api/objects/proxy/"
