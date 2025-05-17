#!/bin/bash
#
# check-pod-resources.sh - Check CPU and memory usage of pods
#
# This script displays the CPU and memory usage of all pods in the namespace,
# with special highlighting for the HAProxy pods.
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

echo -e "${BOLD}=== Pod Resource Usage in Namespace: $NAMESPACE ===${NC}"
echo ""

# Check if metrics-server is installed
if ! kubectl get apiservice v1beta1.metrics.k8s.io &>/dev/null; then
    echo -e "${RED}Error: metrics-server is not installed.${NC}"
    echo "Please install metrics-server to use this script:"
    echo "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    exit 1
fi

# Get pod resource usage
echo -e "${BOLD}Fetching pod resource usage...${NC}"
echo ""

# Print header
printf "${BOLD}%-50s %-10s %-15s %-10s %-15s${NC}\n" "POD NAME" "CPU" "CPU REQUEST" "MEMORY" "MEMORY REQUEST"
printf "%-50s %-10s %-15s %-10s %-15s\n" "$(printf '%.0s-' {1..50})" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..15})"

# Get all pods
PODS=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

for POD in $PODS; do
    # Get CPU and memory usage
    CPU=$(kubectl top pod $POD -n $NAMESPACE --no-headers | awk '{print $2}')
    MEMORY=$(kubectl top pod $POD -n $NAMESPACE --no-headers | awk '{print $3}')
    
    # Get CPU and memory requests
    CPU_REQUEST=$(kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "N/A")
    MEMORY_REQUEST=$(kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "N/A")
    
    # Check if pod is HAProxy
    if [[ $POD == *"haproxy"* ]]; then
        # Highlight HAProxy pods
        printf "${YELLOW}%-50s %-10s %-15s %-10s %-15s${NC}\n" "$POD" "$CPU" "$CPU_REQUEST" "$MEMORY" "$MEMORY_REQUEST"
    else
        printf "%-50s %-10s %-15s %-10s %-15s\n" "$POD" "$CPU" "$CPU_REQUEST" "$MEMORY" "$MEMORY_REQUEST"
    fi
done

echo ""
echo -e "${BOLD}=== HAProxy Specific Information ===${NC}"
echo ""

# Get HAProxy pods
HAPROXY_PODS=$(kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
REDIS_PROXY_PODS=$(kubectl get pods -n $NAMESPACE -l "app=redis-tcp-proxy" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

# Check HAProxy Ingress pods
if [ -n "$HAPROXY_PODS" ]; then
    echo -e "${BOLD}HAProxy Ingress Pods:${NC}"
    for POD in $HAPROXY_PODS; do
        echo -e "${YELLOW}Pod: $POD${NC}"
        
        # Get detailed CPU and memory usage
        echo "Resource usage:"
        kubectl top pod $POD -n $NAMESPACE
        
        # Get resource limits and requests
        echo "Resource limits and requests:"
        kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources}' | python3 -m json.tool 2>/dev/null || echo "No resource limits or requests defined."
        
        # Get number of connections
        echo "Number of connections:"
        kubectl exec -it $POD -n $NAMESPACE -- sh -c "echo 'show stat' | socat unix-connect:/var/run/haproxy/admin.sock stdio | grep FRONTEND | awk '{print \$1,\$2,\$8}'" 2>/dev/null || echo "Could not get connection information."
        
        echo ""
    done
fi

# Check Redis TCP proxy pods
if [ -n "$REDIS_PROXY_PODS" ]; then
    echo -e "${BOLD}Redis TCP Proxy Pods:${NC}"
    for POD in $REDIS_PROXY_PODS; do
        echo -e "${YELLOW}Pod: $POD${NC}"
        
        # Get detailed CPU and memory usage
        echo "Resource usage:"
        kubectl top pod $POD -n $NAMESPACE
        
        # Get resource limits and requests
        echo "Resource limits and requests:"
        kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources}' | python3 -m json.tool 2>/dev/null || echo "No resource limits or requests defined."
        
        # Get HAProxy stats
        echo "HAProxy stats:"
        kubectl exec -it $POD -n $NAMESPACE -- sh -c "echo 'show info' | socat stdio /var/run/haproxy/admin.sock" 2>/dev/null || echo "Could not get HAProxy stats."
        
        echo ""
    done
fi

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
