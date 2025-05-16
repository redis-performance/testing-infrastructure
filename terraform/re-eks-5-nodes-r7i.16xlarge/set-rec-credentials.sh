#!/bin/bash

# Script to set environment variables for Redis Enterprise Cluster credentials

# Get the username and password from the Kubernetes secret
REC_USERNAME=$(kubectl get secret rec-large-scale-5nodes -o jsonpath='{.data.username}' | base64 --decode)
REC_PASSWORD=$(kubectl get secret rec-large-scale-5nodes -o jsonpath='{.data.password}' | base64 --decode)

# Set environment variables
export REC_USERNAME
export REC_PASSWORD

# Print the credentials
echo "Redis Enterprise Cluster credentials:"
echo "Username: $REC_USERNAME"
echo "Password: $REC_PASSWORD"

# Get the UI URL
REC_UI_SERVICE_TYPE=$(kubectl get service rec-large-scale-5nodes-ui -o jsonpath='{.spec.type}')

if [ "$REC_UI_SERVICE_TYPE" == "LoadBalancer" ]; then
    REC_UI_SERVICE=$(kubectl get service rec-large-scale-5nodes-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -n "$REC_UI_SERVICE" ]; then
        echo "Redis Enterprise Cluster UI: https://$REC_UI_SERVICE:8443"
        export REC_UI_URL="https://$REC_UI_SERVICE:8443"
    else
        echo "Redis Enterprise Cluster UI LoadBalancer not ready yet."
        echo "You can check it later with: kubectl get service rec-large-scale-5nodes-ui"
    fi
elif [ "$REC_UI_SERVICE_TYPE" == "ClusterIP" ]; then
    REC_UI_CLUSTER_IP=$(kubectl get service rec-large-scale-5nodes-ui -o jsonpath='{.spec.clusterIP}')
    echo "Redis Enterprise Cluster UI is only accessible from within the cluster at: https://$REC_UI_CLUSTER_IP:8443"
    echo "To access it from your local machine, you can use port-forwarding:"
    echo "kubectl port-forward service/rec-large-scale-5nodes-ui 8443:8443"
    echo "Then access the UI at: https://localhost:8443"
    export REC_UI_URL="https://localhost:8443 (after port-forwarding)"
else
    echo "Redis Enterprise Cluster UI service not found or not ready yet."
    echo "You can check it later with: kubectl get service rec-large-scale-5nodes-ui"
fi

echo ""
echo "Environment variables REC_USERNAME, REC_PASSWORD, and REC_UI_URL (if available) have been set."
echo "To use these variables in your current shell, source this script:"
echo "source ./set-rec-credentials.sh"
