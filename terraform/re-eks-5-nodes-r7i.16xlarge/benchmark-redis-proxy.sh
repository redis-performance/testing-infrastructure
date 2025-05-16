#!/bin/bash
#
# benchmark-redis-proxy.sh - Benchmark Redis TCP proxy performance
#
# This script benchmarks the performance of the Redis TCP proxy to ensure
# it is not becoming a bottleneck.
#

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
PROXY_PORT="12000"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== Benchmarking Redis TCP Proxy Performance ===${NC}"
echo ""

# Get the LoadBalancer hostname for the TCP proxy
echo -e "${BOLD}Step 1: Getting the LoadBalancer hostname for the TCP proxy...${NC}"
LB_HOSTNAME=$(kubectl get service redis-tcp-proxy -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -z "$LB_HOSTNAME" ]; then
    echo -e "${RED}Error: LoadBalancer hostname not available. Please make sure the TCP proxy is running.${NC}"
    exit 1
fi
echo "LoadBalancer hostname: $LB_HOSTNAME"

# Get the database password
echo ""
echo -e "${BOLD}Step 2: Getting the database password...${NC}"
PASSWORD=$(kubectl get secret redb-$DB_NAME -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode 2>/dev/null)
if [ -z "$PASSWORD" ]; then
    echo -e "${RED}Error: Could not retrieve the database password.${NC}"
    exit 1
fi
echo "Database password retrieved."

# Check if redis-cli is installed
echo ""
echo -e "${BOLD}Step 3: Checking if redis-cli is installed...${NC}"
if ! command -v redis-cli &> /dev/null; then
    echo -e "${RED}Error: redis-cli is not installed.${NC}"
    echo "Please install redis-cli using your package manager."
    echo "For example: sudo apt-get install redis-tools"
    exit 1
fi
echo "redis-cli is installed."

# Check if redis-benchmark is installed
echo ""
echo -e "${BOLD}Step 4: Checking if redis-benchmark is installed...${NC}"
if ! command -v redis-benchmark &> /dev/null; then
    echo -e "${RED}Error: redis-benchmark is not installed.${NC}"
    echo "Please install redis-benchmark using your package manager."
    echo "For example: sudo apt-get install redis-tools"
    exit 1
fi
echo "redis-benchmark is installed."

# Run a simple ping test
echo ""
echo -e "${BOLD}Step 5: Running a simple ping test...${NC}"
echo "Command: redis-cli -h $LB_HOSTNAME -p $PROXY_PORT -a $PASSWORD PING"
PING_RESULT=$(redis-cli -h "$LB_HOSTNAME" -p "$PROXY_PORT" -a "$PASSWORD" PING 2>&1)
if [ "$PING_RESULT" = "PONG" ]; then
    echo -e "${GREEN}Ping test successful!${NC}"
else
    echo -e "${RED}Ping test failed: $PING_RESULT${NC}"
    exit 1
fi

# Run a simple benchmark
echo ""
echo -e "${BOLD}Step 6: Running a simple benchmark...${NC}"
echo "Command: redis-benchmark -h $LB_HOSTNAME -p $PROXY_PORT -a $PASSWORD -t ping,set,get -n 10000 -q"
redis-benchmark -h "$LB_HOSTNAME" -p "$PROXY_PORT" -a "$PASSWORD" -t ping,set,get -n 10000 -q

# Run a more comprehensive benchmark
echo ""
echo -e "${BOLD}Step 7: Running a more comprehensive benchmark...${NC}"
echo "Command: redis-benchmark -h $LB_HOSTNAME -p $PROXY_PORT -a $PASSWORD -t ping,set,get,incr,lpush,rpush,lpop,rpop,sadd,hset,spop,lrange -n 10000 -q"
redis-benchmark -h "$LB_HOSTNAME" -p "$PROXY_PORT" -a "$PASSWORD" -t ping,set,get,incr,lpush,rpush,lpop,rpop,sadd,hset,spop,lrange -n 10000 -q

# Run a pipeline benchmark
echo ""
echo -e "${BOLD}Step 8: Running a pipeline benchmark...${NC}"
echo "Command: redis-benchmark -h $LB_HOSTNAME -p $PROXY_PORT -a $PASSWORD -t ping,set,get -n 10000 -P 10 -q"
redis-benchmark -h "$LB_HOSTNAME" -p "$PROXY_PORT" -a "$PASSWORD" -t ping,set,get -n 10000 -P 10 -q

# Check HAProxy status
echo ""
echo -e "${BOLD}Step 9: Checking HAProxy status...${NC}"
echo "Redis TCP Proxy Pod:"
REDIS_PROXY_POD=$(kubectl get pods -n $NAMESPACE -l "app=redis-tcp-proxy" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$REDIS_PROXY_POD" ]; then
    echo "Pod: $REDIS_PROXY_POD"
    
    # Get pod status
    echo "Pod status:"
    kubectl get pod $REDIS_PROXY_POD -n $NAMESPACE -o wide
    
    # Get HAProxy configuration
    echo "HAProxy configuration:"
    kubectl exec -it $REDIS_PROXY_POD -n $NAMESPACE -- cat /usr/local/etc/haproxy/haproxy.cfg || echo "Could not get HAProxy configuration."
else
    echo "No Redis TCP Proxy pod found."
fi

echo ""
echo -e "${BOLD}=== Benchmark Complete ===${NC}"
echo ""
echo "If the Redis TCP proxy is becoming a bottleneck, consider the following:"
echo ""
echo "1. Increase resources for the Redis TCP proxy pod:"
echo "   kubectl patch deployment redis-tcp-proxy -n $NAMESPACE --type=json -p='[{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/resources/requests/cpu\", \"value\": \"500m\"}]'"
echo ""
echo "2. Scale up the Redis TCP proxy deployment:"
echo "   kubectl scale deployment redis-tcp-proxy -n $NAMESPACE --replicas=3"
echo ""
echo "3. Optimize HAProxy configuration:"
echo "   - Increase maxconn"
echo "   - Tune timeouts"
echo "   - Optimize TCP settings"
echo ""
echo "4. Use dedicated nodes for the Redis TCP proxy:"
echo "   - Add node selectors"
echo "   - Use node affinity"
echo ""
echo "5. Monitor HAProxy metrics:"
echo "   - Enable Prometheus metrics"
echo "   - Set up Grafana dashboards"
