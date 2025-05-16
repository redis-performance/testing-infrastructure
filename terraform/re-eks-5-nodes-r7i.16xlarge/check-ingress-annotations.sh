#!/bin/bash
#
# check-ingress-annotations.sh - Check Ingress annotations for Redis Enterprise Database
#
# This script checks if the correct annotations are set on the Ingress resource
# for Redis Enterprise Database access.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
DB_NAME="primary"
INGRESS_NAME="primary-haproxy-ingress"

echo "=== Checking Ingress Annotations for Redis Enterprise Database ==="
echo ""

# Get Ingress resource
echo "Step 1: Retrieving Ingress resource..."
INGRESS_EXISTS=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" 2>/dev/null)
if [ -z "$INGRESS_EXISTS" ]; then
    echo "Error: Ingress resource $INGRESS_NAME not found."
    echo "Please make sure the Ingress resource exists."
    exit 1
fi
echo "Ingress resource $INGRESS_NAME found."

# Check annotations
echo ""
echo "Step 2: Checking annotations..."
ANNOTATIONS=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations}')
echo "Annotations: $ANNOTATIONS"

# Check for SSL passthrough annotation
echo ""
echo "Step 3: Checking for SSL passthrough annotation..."
SSL_PASSTHROUGH=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.haproxy\.org/ssl-passthrough}' 2>/dev/null)
if [ "$SSL_PASSTHROUGH" = "true" ]; then
    echo "SSL passthrough annotation is set to true."
else
    echo "Warning: SSL passthrough annotation is not set to true."
    echo "This is required for Redis Enterprise Database access."
    echo ""
    echo "To fix this, run the following command:"
    echo "kubectl annotate ingress $INGRESS_NAME -n $NAMESPACE haproxy.org/ssl-passthrough=true --overwrite"
fi

# Check for SSL redirect annotation
echo ""
echo "Step 4: Checking for SSL redirect annotation..."
SSL_REDIRECT=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.haproxy\.org/ssl-redirect}' 2>/dev/null)
if [ "$SSL_REDIRECT" = "true" ]; then
    echo "SSL redirect annotation is set to true."
else
    echo "Warning: SSL redirect annotation is not set to true."
    echo "This is recommended for Redis Enterprise Database access."
    echo ""
    echo "To fix this, run the following command:"
    echo "kubectl annotate ingress $INGRESS_NAME -n $NAMESPACE haproxy.org/ssl-redirect=true --overwrite"
fi

# Check Ingress class
echo ""
echo "Step 5: Checking Ingress class..."
INGRESS_CLASS=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ingressClassName}' 2>/dev/null)
if [ "$INGRESS_CLASS" = "haproxy" ]; then
    echo "Ingress class is set to haproxy."
else
    echo "Warning: Ingress class is not set to haproxy."
    echo "This is required for HAProxy Ingress controller to process this Ingress resource."
    echo ""
    echo "To fix this, edit the Ingress resource and set spec.ingressClassName to haproxy."
fi

# Check backend service and port
echo ""
echo "Step 6: Checking backend service and port..."
SERVICE_NAME=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null)
SERVICE_PORT=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)

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
        echo ""
        echo "To fix this, edit the primary-haproxy.yaml file and update the port number to $DB_PORT."
        echo "Then apply the changes with: kubectl apply -f primary-haproxy.yaml"
    fi
else
    echo "Warning: Backend service or port not found."
    echo "Ingress resource might not be correctly configured for Redis Enterprise Database access."
fi

# Check host
echo ""
echo "Step 7: Checking host..."
HOST=$(kubectl get ingress "$INGRESS_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
if [ -n "$HOST" ]; then
    echo "Host: $HOST"
    
    # Check if the host is resolvable
    if nslookup "$HOST" &>/dev/null; then
        echo "Host is resolvable."
    else
        echo "Warning: Host is not resolvable."
        echo "You might need to add an entry to your /etc/hosts file or use the LoadBalancer hostname."
    fi
else
    echo "Warning: Host not found."
    echo "Ingress resource might not be correctly configured for Redis Enterprise Database access."
fi

echo ""
echo "=== Ingress Annotations Check Complete ==="
echo ""
echo "If you need to update the Ingress resource, you can use the following commands:"
echo ""
echo "# Set SSL passthrough annotation"
echo "kubectl annotate ingress $INGRESS_NAME -n $NAMESPACE haproxy.org/ssl-passthrough=true --overwrite"
echo ""
echo "# Set SSL redirect annotation"
echo "kubectl annotate ingress $INGRESS_NAME -n $NAMESPACE haproxy.org/ssl-redirect=true --overwrite"
echo ""
echo "# Update the Ingress resource with the correct port"
echo "kubectl edit ingress $INGRESS_NAME -n $NAMESPACE"
echo ""
echo "For more detailed troubleshooting, run the inspect-haproxy-config.sh script."
