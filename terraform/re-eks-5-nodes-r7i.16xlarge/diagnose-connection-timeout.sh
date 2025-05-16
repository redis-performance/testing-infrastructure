#!/bin/bash
#
# diagnose-connection-timeout.sh - Diagnose connection timeout issues
#
# This script diagnoses connection timeout issues when connecting to a Redis Enterprise Database
# from outside the Kubernetes cluster.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
LB_HOSTNAME=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}' 2>/dev/null)

echo "=== Diagnosing Connection Timeout Issues ==="
echo ""
echo "LoadBalancer hostname: $LB_HOSTNAME"
echo "Database name: $DB_NAME"
echo "Database port: $DB_PORT"
echo ""

# Check if the LoadBalancer hostname is resolvable
echo "Step 1: Checking if the LoadBalancer hostname is resolvable..."
if nslookup "$LB_HOSTNAME" &>/dev/null; then
    echo "LoadBalancer hostname is resolvable."
    echo "IP addresses:"
    nslookup "$LB_HOSTNAME" | grep "Address" | grep -v "#"
else
    echo "Error: LoadBalancer hostname is not resolvable."
    echo "Please check your DNS configuration."
    exit 1
fi

# Check if the port is reachable using telnet
echo ""
echo "Step 2: Checking if the port is reachable using telnet..."
echo "Command: timeout 5 telnet $LB_HOSTNAME $DB_PORT"
timeout 5 telnet "$LB_HOSTNAME" "$DB_PORT" 2>&1 || echo "Telnet connection failed or timed out."

# Check if the port is reachable using nc
echo ""
echo "Step 3: Checking if the port is reachable using nc..."
echo "Command: timeout 5 nc -v $LB_HOSTNAME $DB_PORT"
timeout 5 nc -v "$LB_HOSTNAME" "$DB_PORT" 2>&1 || echo "Netcat connection failed or timed out."

# Check AWS security groups
echo ""
echo "Step 4: Checking AWS security groups..."
echo "This requires AWS CLI and appropriate permissions."
echo "Command: aws ec2 describe-security-groups --filters Name=group-name,Values=*$NAMESPACE* --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,InboundRules:IpPermissions}'"
aws ec2 describe-security-groups --filters "Name=group-name,Values=*$NAMESPACE*" --query 'SecurityGroups[*].{Name:GroupName,ID:GroupId,InboundRules:IpPermissions}' 2>/dev/null || echo "Could not retrieve security group information."

# Check if HAProxy Ingress is correctly configured for TCP passthrough
echo ""
echo "Step 5: Checking if HAProxy Ingress is correctly configured for TCP passthrough..."
HAPROXY_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$HAPROXY_POD" ]; then
    echo "HAProxy Ingress pod: $HAPROXY_POD"
    echo "Checking HAProxy configuration..."
    kubectl exec -it "$HAPROXY_POD" -n "$NAMESPACE" -- cat /etc/haproxy/haproxy.cfg | grep -A 10 "mode tcp" || echo "TCP mode not found in HAProxy configuration."
else
    echo "Error: HAProxy Ingress pod not found."
fi

# Check if the Ingress resource is correctly configured
echo ""
echo "Step 6: Checking if the Ingress resource is correctly configured..."
INGRESS_NAME="primary-haproxy-ingress"
INGRESS_EXISTS=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" 2>/dev/null)
if [ -n "$INGRESS_EXISTS" ]; then
    echo "Ingress resource: $INGRESS_NAME"
    echo "Checking Ingress annotations..."
    kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations}' | grep -q "ssl-passthrough" && echo "SSL passthrough annotation found." || echo "SSL passthrough annotation not found."
    echo "Checking Ingress backend..."
    BACKEND_SERVICE=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}')
    BACKEND_PORT=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}')
    echo "Backend service: $BACKEND_SERVICE"
    echo "Backend port: $BACKEND_PORT"
    if [ "$BACKEND_PORT" != "$DB_PORT" ]; then
        echo "Warning: Backend port ($BACKEND_PORT) does not match database port ($DB_PORT)."
        echo "This could be causing the connection timeout."
    fi
else
    echo "Error: Ingress resource $INGRESS_NAME not found."
fi

# Check if the database is accessible from inside the cluster
echo ""
echo "Step 7: Checking if the database is accessible from inside the cluster..."
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "app=redis-enterprise" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD_NAME" ]; then
    echo "Redis Enterprise pod: $POD_NAME"
    echo "Checking internal connectivity..."
    CLUSTER_NAME=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.redisEnterpriseCluster.name}' 2>/dev/null)
    if [ -n "$CLUSTER_NAME" ]; then
        INTERNAL_HOST="redis-$DB_PORT.$CLUSTER_NAME.$NAMESPACE.svc.cluster.local"
    else
        INTERNAL_HOST="redis-$DB_PORT.$NAMESPACE.svc.cluster.local"
    fi
    echo "Internal hostname: $INTERNAL_HOST"
    echo "Command: kubectl exec -it $POD_NAME -c redis-enterprise-node -n $NAMESPACE -- timeout 5 telnet $INTERNAL_HOST $DB_PORT"
    kubectl exec -it "$POD_NAME" -c redis-enterprise-node -n "$NAMESPACE" -- timeout 5 telnet "$INTERNAL_HOST" "$DB_PORT" 2>&1 || echo "Internal telnet connection failed or timed out."
else
    echo "Error: Redis Enterprise pod not found."
fi

# Check if the database is running and active
echo ""
echo "Step 8: Checking if the database is running and active..."
DB_STATUS=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.status}' 2>/dev/null)
echo "Database status: $DB_STATUS"
if [ "$DB_STATUS" != "active" ]; then
    echo "Warning: Database is not active. This could be causing the connection timeout."
fi

# Check network policies
echo ""
echo "Step 9: Checking network policies..."
NETWORK_POLICIES=$(kubectl get networkpolicies -n "$NAMESPACE" 2>/dev/null)
if [ -n "$NETWORK_POLICIES" ]; then
    echo "Network policies found:"
    kubectl get networkpolicies -n "$NAMESPACE"
    echo "These network policies might be blocking the connection."
else
    echo "No network policies found."
fi

echo ""
echo "=== Connection Timeout Diagnosis Complete ==="
echo ""
echo "Based on the diagnosis, here are some potential solutions:"
echo ""
echo "1. Check AWS security groups to ensure they allow traffic on port $DB_PORT."
echo "2. Make sure HAProxy Ingress is correctly configured for TCP passthrough."
echo "3. Verify that the Ingress resource has the correct annotations and backend configuration."
echo "4. Check if the database is accessible from inside the cluster."
echo "5. Ensure that the database is running and active."
echo "6. Check for network policies that might be blocking the connection."
echo ""
echo "For more detailed troubleshooting, run the following commands:"
echo ""
echo "# Check HAProxy Ingress logs"
echo "kubectl logs $HAPROXY_POD -n $NAMESPACE"
echo ""
echo "# Check Redis Enterprise pod logs"
echo "kubectl logs $POD_NAME -c redis-enterprise-node -n $NAMESPACE"
echo ""
echo "# Check database status"
echo "kubectl describe redb $DB_NAME -n $NAMESPACE"
