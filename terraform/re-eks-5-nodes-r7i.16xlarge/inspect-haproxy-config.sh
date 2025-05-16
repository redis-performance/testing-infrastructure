#!/bin/bash
#
# inspect-haproxy-config.sh - Inspect HAProxy Ingress configuration
#
# This script inspects the HAProxy Ingress configuration to verify it's correctly
# set up for Redis Enterprise Database access.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
INGRESS_NAME="primary-haproxy-ingress"

echo "=== Inspecting HAProxy Ingress Configuration ==="
echo ""

# Get HAProxy Ingress pod
echo "Step 1: Finding HAProxy Ingress pod..."
HAPROXY_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$HAPROXY_POD" ]; then
    echo "Error: HAProxy Ingress pod not found."
    echo "Please make sure HAProxy Ingress is installed and running."
    exit 1
fi
echo "HAProxy Ingress pod: $HAPROXY_POD"

# Check HAProxy Ingress version
echo ""
echo "Step 2: Checking HAProxy Ingress version..."
kubectl exec -it "$HAPROXY_POD" -n "$NAMESPACE" -- haproxy -v 2>/dev/null || echo "Could not get HAProxy version."

# Check HAProxy Ingress configuration
echo ""
echo "Step 3: Checking HAProxy Ingress configuration..."
echo "Retrieving HAProxy configuration file..."
kubectl exec -it "$HAPROXY_POD" -n "$NAMESPACE" -- cat /etc/haproxy/haproxy.cfg > haproxy.cfg 2>/dev/null || echo "Could not retrieve HAProxy configuration."

if [ -f "haproxy.cfg" ]; then
    echo "HAProxy configuration file retrieved successfully."
    echo ""
    echo "Checking for SSL passthrough configuration..."
    if grep -q "ssl-passthrough" haproxy.cfg; then
        echo "SSL passthrough is configured."
        grep -A 10 "ssl-passthrough" haproxy.cfg
    else
        echo "Warning: SSL passthrough configuration not found."
        echo "HAProxy might not be correctly configured for Redis Enterprise Database access."
    fi
    
    echo ""
    echo "Checking for TCP mode configuration..."
    if grep -q "mode tcp" haproxy.cfg; then
        echo "TCP mode is configured."
        grep -A 5 "mode tcp" haproxy.cfg
    else
        echo "Warning: TCP mode configuration not found."
        echo "HAProxy might not be correctly configured for Redis Enterprise Database access."
    fi
    
    echo ""
    echo "Checking for backend configuration for Redis Enterprise Database..."
    if grep -q "$DB_NAME" haproxy.cfg; then
        echo "Backend configuration for $DB_NAME found."
        grep -A 10 "$DB_NAME" haproxy.cfg
    else
        echo "Warning: Backend configuration for $DB_NAME not found."
        echo "HAProxy might not be correctly configured for Redis Enterprise Database access."
    fi
fi

# Check Ingress resource
echo ""
echo "Step 4: Checking Ingress resource..."
echo "Retrieving Ingress resource..."
kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o yaml > ingress.yaml 2>/dev/null || echo "Could not retrieve Ingress resource."

if [ -f "ingress.yaml" ]; then
    echo "Ingress resource retrieved successfully."
    echo ""
    echo "Checking for SSL passthrough annotation..."
    if grep -q "ssl-passthrough" ingress.yaml; then
        echo "SSL passthrough annotation found."
        grep -A 2 "ssl-passthrough" ingress.yaml
    else
        echo "Warning: SSL passthrough annotation not found."
        echo "Ingress resource might not be correctly configured for Redis Enterprise Database access."
    fi
    
    echo ""
    echo "Checking for backend service and port..."
    SERVICE_NAME=$(grep -A 10 "backend:" ingress.yaml | grep "name:" | head -1 | awk '{print $2}')
    SERVICE_PORT=$(grep -A 10 "backend:" ingress.yaml | grep "number:" | head -1 | awk '{print $2}')
    
    if [ -n "$SERVICE_NAME" ] && [ -n "$SERVICE_PORT" ]; then
        echo "Backend service: $SERVICE_NAME"
        echo "Backend port: $SERVICE_PORT"
        
        # Check if the service exists
        if kubectl get service "$SERVICE_NAME" -n "$NAMESPACE" &>/dev/null; then
            echo "Service $SERVICE_NAME exists."
        else
            echo "Warning: Service $SERVICE_NAME does not exist."
            echo "Ingress resource might be pointing to a non-existent service."
        fi
        
        # Check if the port matches the database port
        DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}' 2>/dev/null)
        if [ -n "$DB_PORT" ] && [ "$SERVICE_PORT" = "$DB_PORT" ]; then
            echo "Service port matches database port: $DB_PORT"
        else
            echo "Warning: Service port ($SERVICE_PORT) does not match database port ($DB_PORT)."
            echo "Ingress resource might be pointing to the wrong port."
        fi
    else
        echo "Warning: Backend service or port not found."
        echo "Ingress resource might not be correctly configured for Redis Enterprise Database access."
    fi
fi

# Check HAProxy Ingress logs
echo ""
echo "Step 5: Checking HAProxy Ingress logs..."
echo "Retrieving HAProxy Ingress logs..."
kubectl logs "$HAPROXY_POD" -n "$NAMESPACE" --tail=50 > haproxy.log 2>/dev/null || echo "Could not retrieve HAProxy Ingress logs."

if [ -f "haproxy.log" ]; then
    echo "HAProxy Ingress logs retrieved successfully."
    echo ""
    echo "Checking for errors..."
    if grep -i "error" haproxy.log; then
        echo "Errors found in HAProxy Ingress logs."
    else
        echo "No errors found in HAProxy Ingress logs."
    fi
    
    echo ""
    echo "Checking for SSL/TLS related messages..."
    if grep -i "ssl" haproxy.log; then
        echo "SSL/TLS related messages found in HAProxy Ingress logs."
    else
        echo "No SSL/TLS related messages found in HAProxy Ingress logs."
    fi
fi

# Clean up temporary files
rm -f haproxy.cfg ingress.yaml haproxy.log

echo ""
echo "=== HAProxy Ingress Configuration Inspection Complete ==="
echo ""
echo "If you're still having issues connecting to the Redis Enterprise Database,"
echo "consider the following:"
echo ""
echo "1. Make sure the HAProxy Ingress controller is configured with SSL passthrough enabled."
echo "2. Make sure the Ingress resource has the ssl-passthrough annotation set to true."
echo "3. Make sure the backend service and port are correctly configured."
echo "4. Check if there are any network policies or security groups blocking the connection."
echo "5. Try connecting from inside the cluster using the test-conn-internal.sh script."
echo ""
echo "For more detailed troubleshooting, run the troubleshooting-guide.sh script."
