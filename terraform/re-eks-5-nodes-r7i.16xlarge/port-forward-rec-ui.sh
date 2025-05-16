#!/bin/bash

# Script to set up port forwarding for Redis Enterprise Cluster UI

# Check if the Redis Enterprise Cluster UI service exists
if ! kubectl get service rec-large-scale-5nodes-ui &>/dev/null; then
    echo "Error: Redis Enterprise Cluster UI service not found."
    echo "Make sure the Redis Enterprise Cluster is deployed and running."
    exit 1
fi

# Get the service type
SERVICE_TYPE=$(kubectl get service rec-large-scale-5nodes-ui -o jsonpath='{.spec.type}')

if [ "$SERVICE_TYPE" == "LoadBalancer" ]; then
    # Get the LoadBalancer hostname
    LB_HOSTNAME=$(kubectl get service rec-large-scale-5nodes-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ -n "$LB_HOSTNAME" ]; then
        echo "Redis Enterprise Cluster UI is accessible via LoadBalancer at:"
        echo "https://$LB_HOSTNAME:8443"
        echo ""
        echo "You can access it directly without port forwarding."
        exit 0
    else
        echo "LoadBalancer hostname not available yet. Falling back to port forwarding."
    fi
fi

# Set up port forwarding
echo "Setting up port forwarding for Redis Enterprise Cluster UI..."
echo "The UI will be accessible at: https://localhost:8443"
echo ""
echo "Press Ctrl+C to stop port forwarding when you're done."
echo ""

# Start port forwarding
kubectl port-forward service/rec-large-scale-5nodes-ui 8443:8443

# This script will keep running until the user presses Ctrl+C
