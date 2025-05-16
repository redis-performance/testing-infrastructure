#!/bin/bash
#
# check-haproxy-status.sh - Check HAProxy status and configuration
#
# This script checks the status and configuration of HAProxy pods to ensure
# they are not becoming a bottleneck.
#

# Configuration
NAMESPACE="rec-large-scale"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== HAProxy Status in Namespace: $NAMESPACE ===${NC}"
echo ""

# Get HAProxy pods
echo -e "${BOLD}Step 1: Getting HAProxy pods...${NC}"
HAPROXY_PODS=$(kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
REDIS_PROXY_PODS=$(kubectl get pods -n $NAMESPACE -l "app=redis-tcp-proxy" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

if [ -z "$HAPROXY_PODS" ] && [ -z "$REDIS_PROXY_PODS" ]; then
    echo -e "${RED}Error: No HAProxy pods found.${NC}"
    exit 1
fi

# Check HAProxy Ingress pods
if [ -n "$HAPROXY_PODS" ]; then
    echo -e "${BOLD}HAProxy Ingress Pods:${NC}"
    for POD in $HAPROXY_PODS; do
        echo -e "${YELLOW}Pod: $POD${NC}"
        
        # Get pod status
        echo "Pod status:"
        kubectl get pod $POD -n $NAMESPACE -o wide
        
        # Get resource limits and requests
        echo "Resource limits and requests:"
        kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources}' | python3 -m json.tool 2>/dev/null || echo "No resource limits or requests defined."
        
        # Get HAProxy process info
        echo "HAProxy process info:"
        kubectl exec -it $POD -n $NAMESPACE -- ps aux | grep haproxy || echo "Could not get process information."
        
        # Get HAProxy version
        echo "HAProxy version:"
        kubectl exec -it $POD -n $NAMESPACE -- haproxy -v || echo "Could not get HAProxy version."
        
        # Get HAProxy configuration
        echo "HAProxy configuration summary:"
        kubectl exec -it $POD -n $NAMESPACE -- grep -A 5 "maxconn\|timeout\|mode" /etc/haproxy/haproxy.cfg | head -20 || echo "Could not get HAProxy configuration."
        
        echo ""
    done
fi

# Check Redis TCP proxy pods
if [ -n "$REDIS_PROXY_PODS" ]; then
    echo -e "${BOLD}Redis TCP Proxy Pods:${NC}"
    for POD in $REDIS_PROXY_PODS; do
        echo -e "${YELLOW}Pod: $POD${NC}"
        
        # Get pod status
        echo "Pod status:"
        kubectl get pod $POD -n $NAMESPACE -o wide
        
        # Get resource limits and requests
        echo "Resource limits and requests:"
        kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources}' | python3 -m json.tool 2>/dev/null || echo "No resource limits or requests defined."
        
        # Get HAProxy process info
        echo "HAProxy process info:"
        kubectl exec -it $POD -n $NAMESPACE -- ps aux | grep haproxy || echo "Could not get process information."
        
        # Get HAProxy version
        echo "HAProxy version:"
        kubectl exec -it $POD -n $NAMESPACE -- haproxy -v || echo "Could not get HAProxy version."
        
        # Get HAProxy configuration
        echo "HAProxy configuration:"
        kubectl exec -it $POD -n $NAMESPACE -- cat /usr/local/etc/haproxy/haproxy.cfg || echo "Could not get HAProxy configuration."
        
        echo ""
    done
fi

# Check HAProxy service
echo -e "${BOLD}Step 2: Checking HAProxy service...${NC}"
kubectl get service haproxy-ingress -n $NAMESPACE -o wide
echo ""

# Check Redis TCP proxy service
echo -e "${BOLD}Step 3: Checking Redis TCP proxy service...${NC}"
kubectl get service redis-tcp-proxy -n $NAMESPACE -o wide
echo ""

# Check HAProxy deployment
echo -e "${BOLD}Step 4: Checking HAProxy deployment...${NC}"
kubectl get deployment haproxy-ingress -n $NAMESPACE -o wide
echo ""

# Check Redis TCP proxy deployment
echo -e "${BOLD}Step 5: Checking Redis TCP proxy deployment...${NC}"
kubectl get deployment redis-tcp-proxy -n $NAMESPACE -o wide
echo ""

echo -e "${BOLD}=== Recommendations ===${NC}"
echo ""
echo "If HAProxy is becoming a bottleneck, consider the following:"
echo ""
echo "1. Increase resources for HAProxy pods:"
echo "   kubectl patch deployment haproxy-ingress -n $NAMESPACE --type=json -p='[{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/resources/requests/cpu\", \"value\": \"500m\"}]'"
echo ""
echo "2. Scale up HAProxy deployment:"
echo "   kubectl scale deployment haproxy-ingress -n $NAMESPACE --replicas=3"
echo ""
echo "3. Optimize HAProxy configuration:"
echo "   - Increase maxconn"
echo "   - Tune timeouts"
echo "   - Enable HTTP/2"
echo ""
echo "4. Use dedicated nodes for HAProxy:"
echo "   - Add node selectors"
echo "   - Use node affinity"
echo ""
echo "5. Monitor HAProxy metrics:"
echo "   - Enable Prometheus metrics"
echo "   - Set up Grafana dashboards"
