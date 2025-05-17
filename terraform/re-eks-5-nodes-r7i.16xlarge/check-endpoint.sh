#!/bin/bash
#
# check-endpoint.sh - Check Redis Enterprise Database endpoint configuration
#
# This script checks the Redis Enterprise Database endpoint configuration and provides
# recommendations for fixing any issues.
#

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
NODE_PORT="30793"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== Checking Redis Enterprise Database Endpoint Configuration ===${NC}"
echo ""

# Step 1: Check if the database exists
echo -e "${BOLD}Step 1: Checking if the database exists...${NC}"
if ! kubectl get redb "$DB_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Error: Database '$DB_NAME' not found in namespace '$NAMESPACE'.${NC}"
    echo "Please make sure the database is deployed and running."
    exit 1
fi

echo -e "${GREEN}Database '$DB_NAME' exists in namespace '$NAMESPACE'.${NC}"

# Step 2: Check database status
echo ""
echo -e "${BOLD}Step 2: Checking database status...${NC}"
DB_STATUS=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.status}')
if [ "$DB_STATUS" != "active" ]; then
    echo -e "${RED}Error: Database '$DB_NAME' is not active (current status: $DB_STATUS).${NC}"
    echo "Please wait for the database to become active before proceeding."
    exit 1
fi

echo -e "${GREEN}Database '$DB_NAME' is active.${NC}"

# Step 3: Check database port
echo ""
echo -e "${BOLD}Step 3: Checking database port...${NC}"
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.databasePort}')
if [ -z "$DB_PORT" ]; then
    echo -e "${RED}Error: Failed to get port for database '$DB_NAME'.${NC}"
    exit 1
fi

echo -e "${GREEN}Database '$DB_NAME' is using port $DB_PORT.${NC}"

# Step 4: Check database service
echo ""
echo -e "${BOLD}Step 4: Checking database service...${NC}"
if ! kubectl get svc "$DB_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Error: Service '$DB_NAME' not found in namespace '$NAMESPACE'.${NC}"
    echo "Please make sure the database service is created."
    exit 1
fi

SVC_PORT=$(kubectl get svc "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
if [ "$SVC_PORT" != "$DB_PORT" ]; then
    echo -e "${YELLOW}Warning: Service port ($SVC_PORT) does not match database port ($DB_PORT).${NC}"
    echo "This might cause connection issues."
else
    echo -e "${GREEN}Service '$DB_NAME' is using the correct port ($SVC_PORT).${NC}"
fi

# Step 5: Check database endpoints
echo ""
echo -e "${BOLD}Step 5: Checking database endpoints...${NC}"
ENDPOINTS=$(kubectl get endpoints "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.subsets[0].addresses[0].ip}:{.subsets[0].ports[0].port}')
if [ -z "$ENDPOINTS" ]; then
    echo -e "${RED}Error: No endpoints found for service '$DB_NAME'.${NC}"
    echo "Please make sure the database pods are running and ready."
    exit 1
fi

echo -e "${GREEN}Database endpoints: $ENDPOINTS${NC}"

# Step 6: Check NodePort service
echo ""
echo -e "${BOLD}Step 6: Checking NodePort service...${NC}"
if ! kubectl get svc "$DB_NAME-nodeport" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Warning: NodePort service '$DB_NAME-nodeport' not found in namespace '$NAMESPACE'.${NC}"
    echo "You can create it using the following command:"
    echo ""
    echo "cat > $DB_NAME-nodeport.yaml << EOF"
    echo "apiVersion: v1"
    echo "kind: Service"
    echo "metadata:"
    echo "  name: $DB_NAME-nodeport"
    echo "  namespace: $NAMESPACE"
    echo "spec:"
    echo "  type: NodePort"
    echo "  ports:"
    echo "  - port: $DB_PORT"
    echo "    targetPort: $DB_PORT"
    echo "    nodePort: $NODE_PORT"
    echo "    protocol: TCP"
    echo "  selector:"
    echo "    redis.io/bdb-1: \"1\""
    echo "EOF"
    echo ""
    echo "kubectl apply -f $DB_NAME-nodeport.yaml"
else
    NODEPORT_PORT=$(kubectl get svc "$DB_NAME-nodeport" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
    echo -e "${GREEN}NodePort service '$DB_NAME-nodeport' exists with port $NODEPORT_PORT.${NC}"
    
    # Check if the NodePort service has endpoints
    NODEPORT_ENDPOINTS=$(kubectl get endpoints "$DB_NAME-nodeport" -n "$NAMESPACE" -o jsonpath='{.subsets[0].addresses[0].ip}:{.subsets[0].ports[0].port}')
    if [ -z "$NODEPORT_ENDPOINTS" ]; then
        echo -e "${RED}Error: No endpoints found for NodePort service '$DB_NAME-nodeport'.${NC}"
        echo "Please check the selector in the NodePort service."
    else
        echo -e "${GREEN}NodePort service endpoints: $NODEPORT_ENDPOINTS${NC}"
    fi
fi

# Step 7: Check HAProxy Ingress
echo ""
echo -e "${BOLD}Step 7: Checking HAProxy Ingress...${NC}"
if ! kubectl get ingress "$DB_NAME-haproxy-ingress" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Warning: HAProxy Ingress '$DB_NAME-haproxy-ingress' not found in namespace '$NAMESPACE'.${NC}"
    echo "You can create it using the following command:"
    echo ""
    echo "cat > $DB_NAME-haproxy.yaml << EOF"
    echo "apiVersion: networking.k8s.io/v1"
    echo "kind: Ingress"
    echo "metadata:"
    echo "  name: $DB_NAME-haproxy-ingress"
    echo "  namespace: $NAMESPACE"
    echo "  annotations:"
    echo "    haproxy.org/ssl-redirect: \"true\""
    echo "    haproxy.org/ssl-passthrough: \"true\""
    echo "spec:"
    echo "  ingressClassName: haproxy"
    echo "  rules:"
    echo "    - host: $DB_NAME-db.example.com"
    echo "      http:"
    echo "        paths:"
    echo "          - path: /"
    echo "            pathType: Prefix"
    echo "            backend:"
    echo "              service:"
    echo "                name: $DB_NAME"
    echo "                port:"
    echo "                  number: $DB_PORT"
    echo "EOF"
    echo ""
    echo "kubectl apply -f $DB_NAME-haproxy.yaml"
else
    echo -e "${GREEN}HAProxy Ingress '$DB_NAME-haproxy-ingress' exists.${NC}"
    
    # Check if the HAProxy Ingress has the correct annotations
    SSL_PASSTHROUGH=$(kubectl get ingress "$DB_NAME-haproxy-ingress" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.haproxy\.org/ssl-passthrough}')
    if [ "$SSL_PASSTHROUGH" != "true" ]; then
        echo -e "${YELLOW}Warning: HAProxy Ingress does not have the 'haproxy.org/ssl-passthrough: \"true\"' annotation.${NC}"
        echo "This is required for Redis TLS connections."
    else
        echo -e "${GREEN}HAProxy Ingress has the correct SSL passthrough annotation.${NC}"
    fi
    
    # Check if the HAProxy Ingress is routing to the correct service and port
    INGRESS_SVC=$(kubectl get ingress "$DB_NAME-haproxy-ingress" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}')
    INGRESS_PORT=$(kubectl get ingress "$DB_NAME-haproxy-ingress" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}')
    if [ "$INGRESS_SVC" != "$DB_NAME" ] || [ "$INGRESS_PORT" != "$DB_PORT" ]; then
        echo -e "${YELLOW}Warning: HAProxy Ingress is not routing to the correct service and port.${NC}"
        echo "Expected: $DB_NAME:$DB_PORT, Actual: $INGRESS_SVC:$INGRESS_PORT"
    else
        echo -e "${GREEN}HAProxy Ingress is routing to the correct service and port.${NC}"
    fi
fi

# Step 8: Check HAProxy LoadBalancer service
echo ""
echo -e "${BOLD}Step 8: Checking HAProxy LoadBalancer service...${NC}"
if ! kubectl get svc haproxy-ingress -n "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}Warning: HAProxy LoadBalancer service 'haproxy-ingress' not found in namespace '$NAMESPACE'.${NC}"
    echo "You can create it by running the haproxy.sh script."
else
    LB_TYPE=$(kubectl get svc haproxy-ingress -n "$NAMESPACE" -o jsonpath='{.spec.type}')
    if [ "$LB_TYPE" != "LoadBalancer" ]; then
        echo -e "${YELLOW}Warning: HAProxy service 'haproxy-ingress' is not of type LoadBalancer.${NC}"
        echo "Expected: LoadBalancer, Actual: $LB_TYPE"
    else
        echo -e "${GREEN}HAProxy service 'haproxy-ingress' is of type LoadBalancer.${NC}"
    fi
    
    LB_IP=$(kubectl get svc haproxy-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -z "$LB_IP" ]; then
        echo -e "${YELLOW}Warning: HAProxy LoadBalancer service does not have an external IP or hostname.${NC}"
        echo "This might be due to the IP address constraints we identified earlier."
    else
        echo -e "${GREEN}HAProxy LoadBalancer hostname: $LB_IP${NC}"
    fi
fi

# Step 9: Provide connection recommendations
echo ""
echo -e "${BOLD}Step 9: Connection recommendations...${NC}"
echo ""
echo "Based on the current configuration, here are the recommended ways to connect to the database:"
echo ""

# NodePort connection
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -n "$NODE_IP" ] && [ -n "$NODEPORT_PORT" ]; then
    echo -e "${BOLD}1. Using NodePort:${NC}"
    echo "   redis-cli -h $NODE_IP -p $NODEPORT_PORT --tls --insecure -a \$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath='{.data.password}' | base64 --decode)"
    echo ""
fi

# HAProxy Ingress connection
if [ -n "$LB_IP" ]; then
    echo -e "${BOLD}2. Using HAProxy Ingress (LoadBalancer):${NC}"
    echo "   redis-cli -h $LB_IP -p 443 --tls --insecure --sni $DB_NAME.$LB_IP -a \$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath='{.data.password}' | base64 --decode)"
    echo ""
fi

# Port forwarding connection
echo -e "${BOLD}3. Using port forwarding:${NC}"
echo "   kubectl port-forward svc/$DB_NAME -n $NAMESPACE $DB_PORT:$DB_PORT"
echo "   redis-cli -p $DB_PORT --tls --insecure -a \$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath='{.data.password}' | base64 --decode)"
echo ""

echo -e "${BOLD}=== Endpoint Configuration Check Complete ===${NC}"
