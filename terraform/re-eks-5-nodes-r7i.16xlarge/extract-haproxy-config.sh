#!/bin/bash
#
# extract-haproxy-config.sh - Extract HAProxy configuration from Redis Enterprise Cluster
#
# This script extracts HAProxy configuration information from Redis Enterprise Cluster
# and compares it with the current HAProxy configuration in Kubernetes.
#

# Configuration
NAMESPACE="rec-large-scale"
CLUSTER_NAME="rec-large-scale-5nodes"
API_PORT="9443"
HAPROXY_DEPLOYMENT="haproxy-ingress"
REDIS_TCP_PROXY="redis-tcp-proxy"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== HAProxy Configuration Analysis ===${NC}"
echo ""

# Get cluster credentials
echo -e "${BOLD}Step 1: Getting cluster credentials...${NC}"
USERNAME=$(kubectl get secret $CLUSTER_NAME -n $NAMESPACE -o jsonpath='{.data.username}' | base64 --decode)
PASSWORD=$(kubectl get secret $CLUSTER_NAME -n $NAMESPACE -o jsonpath='{.data.password}' | base64 --decode)

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

# Get database information
echo ""
echo -e "${BOLD}Step 3: Getting database information...${NC}"
echo "Retrieving database information from the REST API..."

# Get all databases
DATABASES=$(curl -s -k -u "$USERNAME:$PASSWORD" https://localhost:$API_PORT/v1/bdbs)

# Check if the request was successful
if [[ $DATABASES == *"error"* ]]; then
    echo -e "${RED}Error: Failed to get database information.${NC}"
    echo "Response: $DATABASES"
    exit 1
fi

# Extract database ports and endpoints
echo ""
echo -e "${BOLD}Database Ports and Endpoints:${NC}"
DB_INFO=$(echo "$DATABASES" | python3 -c "
import sys, json
databases = json.load(sys.stdin)
for db in databases:
    print(f\"Database: {db.get('name', 'N/A')} (ID: {db.get('uid', 'N/A')}):\")
    print(f\"  Port: {db.get('port', 'N/A')}\")
    print(f\"  Proxy Policy: {db.get('proxy_policy', 'N/A')}\")
    print(f\"  SSL: {'Enabled' if db.get('ssl', False) else 'Disabled'}\")
    
    endpoints = db.get('endpoints', [])
    if endpoints:
        print(\"  Endpoints:\")
        for endpoint in endpoints:
            print(f\"    - {endpoint.get('addr_type', 'N/A')}: {endpoint.get('dns_name', 'N/A')}:{endpoint.get('port', 'N/A')}\")
    
    print()
")

echo "$DB_INFO"

# Get HAProxy configuration
echo ""
echo -e "${BOLD}Step 4: Getting HAProxy configuration...${NC}"
echo "Retrieving HAProxy configuration from Kubernetes..."

# Get HAProxy pods
HAPROXY_PODS=$(kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/name=$HAPROXY_DEPLOYMENT" -o jsonpath='{.items[*].metadata.name}')
if [ -z "$HAPROXY_PODS" ]; then
    echo -e "${RED}Error: No HAProxy pods found.${NC}"
    echo "Please make sure HAProxy is deployed and running."
else
    # Get HAProxy configuration
    for POD in $HAPROXY_PODS; do
        echo ""
        echo -e "${YELLOW}HAProxy configuration for pod $POD:${NC}"
        kubectl exec -n $NAMESPACE $POD -- cat /etc/haproxy/haproxy.cfg | grep -A 10 "backend" | grep -v "#" || echo "Could not get HAProxy configuration."
    done
fi

# Get Redis TCP proxy configuration
echo ""
echo -e "${BOLD}Step 5: Getting Redis TCP proxy configuration...${NC}"
echo "Retrieving Redis TCP proxy configuration from Kubernetes..."

# Get Redis TCP proxy pods
REDIS_TCP_PODS=$(kubectl get pods -n $NAMESPACE -l "app=$REDIS_TCP_PROXY" -o jsonpath='{.items[*].metadata.name}')
if [ -z "$REDIS_TCP_PODS" ]; then
    echo -e "${RED}Error: No Redis TCP proxy pods found.${NC}"
    echo "Please make sure Redis TCP proxy is deployed and running."
else
    # Get Redis TCP proxy configuration
    for POD in $REDIS_TCP_PODS; do
        echo ""
        echo -e "${YELLOW}Redis TCP proxy configuration for pod $POD:${NC}"
        kubectl exec -n $NAMESPACE $POD -- cat /usr/local/etc/haproxy/haproxy.cfg || echo "Could not get Redis TCP proxy configuration."
    done
fi

# Compare database ports with HAProxy configuration
echo ""
echo -e "${BOLD}Step 6: Analyzing configuration...${NC}"
echo "Comparing database ports with HAProxy configuration..."

# Extract database ports
DB_PORTS=$(echo "$DATABASES" | python3 -c "
import sys, json
databases = json.load(sys.stdin)
for db in databases:
    print(f\"{db.get('name', 'N/A')}:{db.get('port', 'N/A')}:{db.get('ssl', False)}\")
")

# Check if Redis TCP proxy is correctly configured
echo ""
echo -e "${BOLD}Redis TCP Proxy Analysis:${NC}"
for DB_PORT_INFO in $DB_PORTS; do
    DB_NAME=$(echo $DB_PORT_INFO | cut -d':' -f1)
    DB_PORT=$(echo $DB_PORT_INFO | cut -d':' -f2)
    DB_SSL=$(echo $DB_PORT_INFO | cut -d':' -f3)
    
    if [ "$DB_NAME" == "primary" ]; then
        echo "Checking configuration for database: $DB_NAME (Port: $DB_PORT, SSL: $DB_SSL)"
        
        # Check if Redis TCP proxy is configured for this database
        if [ -n "$REDIS_TCP_PODS" ]; then
            for POD in $REDIS_TCP_PODS; do
                TCP_PROXY_CONFIG=$(kubectl exec -n $NAMESPACE $POD -- cat /usr/local/etc/haproxy/haproxy.cfg)
                
                if [[ $TCP_PROXY_CONFIG == *"$DB_PORT"* ]]; then
                    echo -e "${GREEN}✓ Redis TCP proxy is correctly configured for database $DB_NAME.${NC}"
                    
                    # Check SSL configuration
                    if [ "$DB_SSL" == "True" ] && [[ $TCP_PROXY_CONFIG == *"ssl verify none"* ]]; then
                        echo -e "${GREEN}✓ SSL configuration is correct.${NC}"
                    elif [ "$DB_SSL" == "True" ] && [[ $TCP_PROXY_CONFIG != *"ssl verify none"* ]]; then
                        echo -e "${RED}✗ Database has SSL enabled, but Redis TCP proxy is not configured for SSL.${NC}"
                    elif [ "$DB_SSL" == "False" ] && [[ $TCP_PROXY_CONFIG == *"ssl verify none"* ]]; then
                        echo -e "${YELLOW}⚠ Database has SSL disabled, but Redis TCP proxy is configured for SSL.${NC}"
                    fi
                else
                    echo -e "${RED}✗ Redis TCP proxy is not configured for database $DB_NAME.${NC}"
                fi
            done
        else
            echo -e "${RED}✗ No Redis TCP proxy pods found.${NC}"
        fi
    fi
done

# Check HAProxy Ingress configuration
echo ""
echo -e "${BOLD}HAProxy Ingress Analysis:${NC}"
for DB_PORT_INFO in $DB_PORTS; do
    DB_NAME=$(echo $DB_PORT_INFO | cut -d':' -f1)
    DB_PORT=$(echo $DB_PORT_INFO | cut -d':' -f2)
    DB_SSL=$(echo $DB_PORT_INFO | cut -d':' -f3)
    
    if [ "$DB_NAME" == "primary" ]; then
        echo "Checking configuration for database: $DB_NAME (Port: $DB_PORT, SSL: $DB_SSL)"
        
        # Check if HAProxy Ingress is configured for this database
        if [ -n "$HAPROXY_PODS" ]; then
            for POD in $HAPROXY_PODS; do
                HAPROXY_CONFIG=$(kubectl exec -n $NAMESPACE $POD -- cat /etc/haproxy/haproxy.cfg)
                
                if [[ $HAPROXY_CONFIG == *"$DB_PORT"* ]]; then
                    echo -e "${GREEN}✓ HAProxy Ingress is correctly configured for database $DB_NAME.${NC}"
                    
                    # Check SSL configuration
                    if [ "$DB_SSL" == "True" ] && [[ $HAPROXY_CONFIG == *"ssl verify none"* ]]; then
                        echo -e "${GREEN}✓ SSL configuration is correct.${NC}"
                    elif [ "$DB_SSL" == "True" ] && [[ $HAPROXY_CONFIG != *"ssl verify none"* ]]; then
                        echo -e "${RED}✗ Database has SSL enabled, but HAProxy Ingress is not configured for SSL.${NC}"
                    elif [ "$DB_SSL" == "False" ] && [[ $HAPROXY_CONFIG == *"ssl verify none"* ]]; then
                        echo -e "${YELLOW}⚠ Database has SSL disabled, but HAProxy Ingress is configured for SSL.${NC}"
                    fi
                else
                    echo -e "${RED}✗ HAProxy Ingress is not configured for database $DB_NAME.${NC}"
                fi
            done
        else
            echo -e "${RED}✗ No HAProxy Ingress pods found.${NC}"
        fi
    fi
done

echo ""
echo -e "${BOLD}=== HAProxy Configuration Analysis Complete ===${NC}"
echo ""
echo "For more information about the Redis Enterprise Cluster REST API, visit:"
echo "https://redis.io/docs/latest/operate/rs/references/rest-api/objects/proxy/"
