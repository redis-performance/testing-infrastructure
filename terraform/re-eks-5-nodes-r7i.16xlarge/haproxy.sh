#!/bin/bash
#
# haproxy.sh - Configure HAProxy Ingress Controller for Redis Enterprise Cluster
#
# This script installs the HAProxy Ingress Controller and configures Ingress resources
# to route external traffic to Redis Enterprise services.
#

set -e  # Exit immediately if a command exits with a non-zero status

# Configuration
NAMESPACE="rec-large-scale"
REC_NAME="rec-large-scale-5nodes"
INGRESS_NAME="haproxy-ingress"
INGRESS_CLASS="haproxy"

echo "Configuring HAProxy Ingress Controller for Redis Enterprise Cluster..."

# Add the HAProxy Ingress Helm repo
echo "Adding HAProxy Ingress Helm repository..."
helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts
helm repo update

# Check if HAProxy Ingress is already installed
if helm list -n $NAMESPACE | grep -q $INGRESS_NAME; then
    echo "HAProxy Ingress is already installed. Upgrading..."
    helm upgrade $INGRESS_NAME haproxy-ingress/haproxy-ingress \
      --namespace $NAMESPACE \
      --set controller.service.type=LoadBalancer
else
    echo "Installing HAProxy Ingress Controller..."
    helm install $INGRESS_NAME haproxy-ingress/haproxy-ingress \
      --namespace $NAMESPACE \
      --create-namespace \
      --set controller.service.type=LoadBalancer
fi

# Wait for the LoadBalancer to get an external IP
echo "Waiting for LoadBalancer to be provisioned..."
for i in {1..30}; do
    if kubectl get svc -n $NAMESPACE $INGRESS_NAME -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | grep -q "."; then
        break
    fi
    echo "Waiting for LoadBalancer hostname... ($i/30)"
    sleep 10
done

# Get the LoadBalancer hostname
LB_HOSTNAME=$(kubectl get svc -n $NAMESPACE $INGRESS_NAME -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$LB_HOSTNAME" ]; then
    echo "Error: Failed to get LoadBalancer hostname. Check the service status:"
    kubectl get svc -n $NAMESPACE $INGRESS_NAME
    exit 1
fi

echo "LoadBalancer hostname: $LB_HOSTNAME"
echo $LB_HOSTNAME > haproxy_hostname.txt

# Create Ingress resources for Redis Enterprise services
echo "Creating Ingress resources for Redis Enterprise services..."

# Create Ingress for Redis Enterprise UI
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rec-ui-ingress
  namespace: $NAMESPACE
  annotations:
    haproxy.org/ssl-redirect: "true"
    haproxy.org/ssl-passthrough: "true"
spec:
  ingressClassName: $INGRESS_CLASS
  rules:
  - host: $LB_HOSTNAME
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $REC_NAME-ui
            port:
              number: 8443
EOF

# Create Ingress for Redis Enterprise API
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rec-api-ingress
  namespace: $NAMESPACE
  annotations:
    haproxy.org/ssl-redirect: "true"
    haproxy.org/ssl-passthrough: "true"
spec:
  ingressClassName: $INGRESS_CLASS
  rules:
  - host: api.$LB_HOSTNAME
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $REC_NAME
            port:
              number: 9443
EOF

echo "HAProxy Ingress Controller and Ingress resources have been configured successfully."
echo ""
echo "You can access the Redis Enterprise Cluster UI at: https://$LB_HOSTNAME"
echo "You can access the Redis Enterprise Cluster API at: https://api.$LB_HOSTNAME"
echo ""
echo "Note: It may take a few minutes for DNS to propagate. If you cannot access the services,"
echo "you may need to add entries to your /etc/hosts file or wait for DNS propagation."
echo ""
echo "To check the status of the Ingress resources, run:"
echo "kubectl get ingress -n $NAMESPACE"
