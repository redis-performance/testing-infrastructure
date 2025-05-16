#!/bin/bash
#
# fix-haproxy-config.sh - Fix HAProxy Ingress configuration for Redis Enterprise Database
#
# This script fixes common HAProxy Ingress configuration issues for Redis Enterprise Database access.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
INGRESS_NAME="primary-haproxy-ingress"

echo "=== Fixing HAProxy Ingress Configuration for Redis Enterprise Database ==="
echo ""

# Get database port
echo "Step 1: Getting database port..."
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}' 2>/dev/null)
if [ -z "$DB_PORT" ]; then
    echo "Error: Failed to get port for database '$DB_NAME'."
    exit 1
fi
echo "Database port: $DB_PORT"

# Check if Ingress resource exists
echo ""
echo "Step 2: Checking if Ingress resource exists..."
INGRESS_EXISTS=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" 2>/dev/null)
if [ -z "$INGRESS_EXISTS" ]; then
    echo "Ingress resource $INGRESS_NAME does not exist."
    echo "Creating Ingress resource..."
    
    # Get the LoadBalancer hostname
    LB_HOSTNAME=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -z "$LB_HOSTNAME" ]; then
        echo "Error: Failed to get LoadBalancer hostname."
        echo "Please make sure HAProxy Ingress is installed and running."
        exit 1
    fi
    
    # Create Ingress resource
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $INGRESS_NAME
  namespace: $NAMESPACE
  annotations:
    haproxy.org/ssl-redirect: "true"
    haproxy.org/ssl-passthrough: "true"
spec:
  ingressClassName: haproxy
  rules:
    - host: primary-db.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $DB_NAME
                port:
                  number: $DB_PORT
EOF
    
    echo "Ingress resource created successfully."
else
    echo "Ingress resource $INGRESS_NAME exists."
    
    # Check if the port is correct
    CURRENT_PORT=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)
    if [ "$CURRENT_PORT" != "$DB_PORT" ]; then
        echo "Updating port from $CURRENT_PORT to $DB_PORT..."
        kubectl patch ingress "$INGRESS_NAME" -n "$NAMESPACE" --type=json -p="[{\"op\": \"replace\", \"path\": \"/spec/rules/0/http/paths/0/backend/service/port/number\", \"value\": $DB_PORT}]"
    else
        echo "Port is already set to $DB_PORT."
    fi
fi

# Set annotations
echo ""
echo "Step 3: Setting annotations..."
echo "Setting SSL passthrough annotation..."
kubectl annotate ingress "$INGRESS_NAME" -n "$NAMESPACE" haproxy.org/ssl-passthrough=true --overwrite
echo "Setting SSL redirect annotation..."
kubectl annotate ingress "$INGRESS_NAME" -n "$NAMESPACE" haproxy.org/ssl-redirect=true --overwrite

# Create Ingress resource for LoadBalancer hostname
echo ""
echo "Step 4: Creating Ingress resource for LoadBalancer hostname..."
# Get the LoadBalancer hostname
LB_HOSTNAME=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -z "$LB_HOSTNAME" ]; then
    echo "Error: Failed to get LoadBalancer hostname."
    echo "Please make sure HAProxy Ingress is installed and running."
    exit 1
fi

# Create Ingress resource for LoadBalancer hostname
LB_INGRESS_NAME="$INGRESS_NAME-$DB_NAME"
echo "Creating Ingress resource $LB_INGRESS_NAME..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $LB_INGRESS_NAME
  namespace: $NAMESPACE
  annotations:
    haproxy.org/ssl-redirect: "true"
    haproxy.org/ssl-passthrough: "true"
spec:
  ingressClassName: haproxy
  rules:
    - host: $DB_NAME.$LB_HOSTNAME
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $DB_NAME
                port:
                  number: $DB_PORT
EOF

echo "Ingress resource $LB_INGRESS_NAME created successfully."

# Save the LoadBalancer hostname to a file
echo "$LB_HOSTNAME" > haproxy_hostname.txt
echo "LoadBalancer hostname saved to haproxy_hostname.txt."

# Restart HAProxy Ingress pod (optional)
echo ""
echo "Step 5: Restarting HAProxy Ingress pod (optional)..."
echo "Would you like to restart the HAProxy Ingress pod? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    HAPROXY_POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=haproxy-ingress" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$HAPROXY_POD" ]; then
        echo "Restarting HAProxy Ingress pod $HAPROXY_POD..."
        kubectl delete pod "$HAPROXY_POD" -n "$NAMESPACE"
        echo "HAProxy Ingress pod restarted successfully."
    else
        echo "Error: HAProxy Ingress pod not found."
    fi
else
    echo "Skipping HAProxy Ingress pod restart."
fi

echo ""
echo "=== HAProxy Ingress Configuration Fixed ==="
echo ""
echo "You can now test the connection to the Redis Enterprise Database using:"
echo ""
echo "# Using the LoadBalancer hostname:"
echo "redis-cli -h $LB_HOSTNAME -p $DB_PORT --tls --insecure --sni $DB_NAME.$LB_HOSTNAME -a <password>"
echo ""
echo "# Or using the Ingress hostname (requires DNS or /etc/hosts entry):"
echo "redis-cli -h primary-db.example.com -p $DB_PORT --tls --insecure -a <password>"
echo ""
echo "For more detailed testing, run the test-redis-cli-insecure.sh script."
