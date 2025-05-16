#!/bin/bash
#
# configure-db-ingress.sh - Configure Ingress for Redis Enterprise Database
#
# This script creates an Ingress resource to route external traffic to a Redis Enterprise Database.
# It dynamically retrieves the database port from the Redis Enterprise Database (REDB) resource.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
INGRESS_CLASS="haproxy"
INGRESS_NAME="primary-haproxy-ingress"
DB_NAME=""
DB_HOST=""
LB_HOSTNAME=""

# Function to display usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Configure Ingress for Redis Enterprise Database."
    echo ""
    echo "Options:"
    echo "  --db-name NAME       Name of the Redis Enterprise Database (required)"
    echo "  --db-host HOSTNAME   Hostname for the database Ingress (default: db-NAME.LOADBALANCER)"
    echo "  --help               Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --db-name mydb"
    echo "  $0 --db-name mydb --db-host mydb.example.com"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --db-name)
            DB_NAME="$2"
            shift 2
            ;;
        --db-host)
            DB_HOST="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if database name is provided
if [ -z "$DB_NAME" ]; then
    echo "Error: Database name is required."
    show_usage
    exit 1
fi

# Check if the database exists
if ! kubectl get redb "$DB_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Error: Redis Enterprise Database '$DB_NAME' not found in namespace '$NAMESPACE'."
    echo "Available databases:"
    kubectl get redb -n "$NAMESPACE"
    exit 1
fi

# Get the database port
DB_PORT=$(kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o jsonpath='{.status.internalEndpoints[0].port}')
if [ -z "$DB_PORT" ]; then
    echo "Error: Failed to get port for database '$DB_NAME'."
    echo "Checking database status..."
    kubectl get redb "$DB_NAME" -n "$NAMESPACE" -o yaml
    exit 1
fi

echo "Database '$DB_NAME' is using port $DB_PORT."

# Get the HAProxy LoadBalancer hostname if needed
if [ -z "$DB_HOST" ]; then
    # Check if haproxy_hostname.txt exists
    if [ -f "haproxy_hostname.txt" ]; then
        LB_HOSTNAME=$(cat haproxy_hostname.txt)
    else
        # Get the LoadBalancer hostname from the HAProxy service
        LB_HOSTNAME=$(kubectl get svc haproxy-ingress -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    fi

    if [ -z "$LB_HOSTNAME" ]; then
        echo "Error: Failed to get LoadBalancer hostname. Make sure HAProxy Ingress is installed."
        echo "Run ./haproxy.sh first to set up HAProxy Ingress."
        exit 1
    fi

    # Set the database host
    DB_HOST="$DB_NAME.$LB_HOSTNAME"
fi

echo "Using hostname: $DB_HOST"

# Create the Ingress resource
echo "Creating Ingress resource for database '$DB_NAME'..."

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $INGRESS_NAME-$DB_NAME
  namespace: $NAMESPACE
  annotations:
    haproxy.org/ssl-redirect: "true"
    haproxy.org/ssl-passthrough: "true"
spec:
  ingressClassName: $INGRESS_CLASS
  rules:
    - host: $DB_HOST
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
echo ""
echo "You can access the Redis Enterprise Database at: redis://$DB_HOST:$DB_PORT"
echo ""
echo "To check the status of the Ingress resource, run:"
echo "kubectl get ingress $INGRESS_NAME-$DB_NAME -n $NAMESPACE"
echo ""
echo "Note: It may take a few minutes for DNS to propagate. If you cannot access the database,"
echo "you may need to add an entry to your /etc/hosts file or wait for DNS propagation."
