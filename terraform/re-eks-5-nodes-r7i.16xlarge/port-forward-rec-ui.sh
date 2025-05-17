#!/bin/bash

# Script to set up port forwarding for Redis Enterprise Cluster UI

# Set AWS credentials

# Update kubeconfig
aws eks update-kubeconfig --region us-east-2 --name re-eks-cluster-5-nodes-r7i-16xlarge

# Set namespace
NAMESPACE="rec-large-scale"

# Check if the Redis Enterprise Cluster UI service exists
echo "Checking for service rec-large-scale-5nodes-ui in namespace $NAMESPACE..."
kubectl get service rec-large-scale-5nodes-ui -n $NAMESPACE
if [ $? -ne 0 ]; then
    echo "Error: Redis Enterprise Cluster UI service not found in namespace $NAMESPACE."
    echo "Make sure the Redis Enterprise Cluster is deployed and running."
    exit 1
fi
echo "Service found!"

# Get the service type
SERVICE_TYPE=$(kubectl get service rec-large-scale-5nodes-ui -n $NAMESPACE -o jsonpath='{.spec.type}')

if [ "$SERVICE_TYPE" == "LoadBalancer" ]; then
    # Get the LoadBalancer hostname
    LB_HOSTNAME=$(kubectl get service rec-large-scale-5nodes-ui -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

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
kubectl port-forward service/rec-large-scale-5nodes-ui -n $NAMESPACE 8443:8443

# This script will keep running until the user presses Ctrl+C
