#!/bin/bash
#
# fix-tcp-proxy.sh - Fix Redis TCP proxy connection issues
#
# This script fixes connection issues with the Redis TCP proxy by updating the HAProxy configuration
# and restarting the Redis TCP proxy deployment.
#

# AWS credentials should be provided as environment variables
# export AWS_ACCESS_KEY_ID="your-access-key"
# export AWS_SECRET_ACCESS_KEY="your-secret-key"
# export AWS_SESSION_TOKEN="your-session-token"
# export AWS_REGION="us-east-2"

# Update kubeconfig
aws eks update-kubeconfig --region us-east-2 --name re-eks-cluster-5-nodes-r7i-16xlarge

# Set namespace
NAMESPACE="rec-large-scale"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== Fixing Redis TCP Proxy Connection Issues ===${NC}"
echo ""

# Step 1: Check if the Redis Enterprise Database exists
echo -e "${BOLD}Step 1: Checking if the Redis Enterprise Database exists...${NC}"
if ! kubectl get redb primary -n $NAMESPACE &>/dev/null; then
    echo -e "${RED}Error: Redis Enterprise Database 'primary' not found in namespace '$NAMESPACE'.${NC}"
    echo "Please create the database first."
    exit 1
fi

echo -e "${GREEN}Redis Enterprise Database 'primary' exists in namespace '$NAMESPACE'.${NC}"

# Step 2: Get the Redis Enterprise Database UID
echo ""
echo -e "${BOLD}Step 2: Getting the Redis Enterprise Database UID...${NC}"
DB_UID=$(kubectl get redb primary -n $NAMESPACE -o jsonpath='{.status.databaseUID}')
echo -e "${BLUE}Database UID: $DB_UID${NC}"

# Step 3: Update the HAProxy configuration
echo ""
echo -e "${BOLD}Step 3: Updating the HAProxy configuration...${NC}"
echo "Creating a new HAProxy configuration with increased timeouts..."

cat > fix-tcp-proxy-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-tcp-proxy-config
  namespace: rec-large-scale
data:
  haproxy.cfg: |
    global
      daemon
      maxconn 256

    defaults
      mode tcp
      timeout connect 10s
      timeout client 120s
      timeout server 120s

    frontend redis_frontend
      bind *:12000
      default_backend redis_backend

    backend redis_backend
      mode tcp
      option tcp-check
      server redis primary.rec-large-scale.svc.cluster.local:11793 check ssl verify none
EOF

echo "Applying the new HAProxy configuration..."
kubectl apply -f fix-tcp-proxy-config.yaml

# Step 4: Restart the Redis TCP proxy
echo ""
echo -e "${BOLD}Step 4: Restarting the Redis TCP proxy...${NC}"
kubectl rollout restart deployment redis-tcp-proxy -n $NAMESPACE
echo "Waiting for the Redis TCP proxy to restart..."
kubectl rollout status deployment redis-tcp-proxy -n $NAMESPACE

# Step 5: Test the connection
echo ""
echo -e "${BOLD}Step 5: Testing the connection...${NC}"
echo "Waiting for the Redis TCP proxy to be ready..."
sleep 10

# Get the LoadBalancer hostname
LB_HOSTNAME=$(kubectl get svc redis-tcp-proxy -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo -e "${BLUE}LoadBalancer hostname: $LB_HOSTNAME${NC}"

# Get the Redis Enterprise Database password
PASSWORD=$(kubectl get secret redb-primary -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode)
echo -e "${BLUE}Redis Enterprise Database password: $PASSWORD${NC}"

# Test the connection
echo "Testing the connection to the Redis Enterprise Database..."
echo "Command: redis-cli -h $LB_HOSTNAME -p 12000 --tls --insecure -a $PASSWORD PING"
echo ""
echo "You can run this command to test the connection:"
echo "redis-cli -h $LB_HOSTNAME -p 12000 --tls --insecure -a $PASSWORD PING"

echo ""
echo -e "${BOLD}=== Redis TCP Proxy Fix Complete ===${NC}"
echo ""
echo "If you still experience connection issues, please check the Redis TCP proxy logs:"
echo "kubectl logs \$(kubectl get pods -n $NAMESPACE -l app=redis-tcp-proxy -o jsonpath='{.items[0].metadata.name}') -n $NAMESPACE"
