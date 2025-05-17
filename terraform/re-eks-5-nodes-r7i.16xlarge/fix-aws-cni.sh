#!/bin/bash
#
# fix-aws-cni.sh - Fix AWS VPC CNI issues
#
# This script helps fix AWS VPC CNI issues that prevent pods from being created.
#


# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== Fixing AWS VPC CNI Issues ===${NC}"
echo ""

# Step 1: Update kubeconfig
echo -e "${BOLD}Step 1: Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region us-east-2 --name re-eks-cluster-5-nodes-r7i-16xlarge
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to update kubeconfig.${NC}"
    echo "Please check if the EKS cluster exists and you have the correct permissions."
    exit 1
fi
echo -e "${GREEN}Kubeconfig updated successfully.${NC}"

# Step 2: Check if the AWS VPC CNI is installed
echo ""
echo -e "${BOLD}Step 2: Checking if the AWS VPC CNI is installed...${NC}"
if kubectl get daemonset aws-node -n kube-system &>/dev/null; then
    echo -e "${YELLOW}AWS VPC CNI DaemonSet exists. Deleting it...${NC}"
    kubectl delete daemonset aws-node -n kube-system
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to delete the AWS VPC CNI DaemonSet.${NC}"
        exit 1
    fi
    echo -e "${GREEN}AWS VPC CNI DaemonSet deleted successfully.${NC}"
else
    echo -e "${GREEN}AWS VPC CNI DaemonSet does not exist.${NC}"
fi

# Step 3: Clean up any existing AWS VPC CNI resources
echo ""
echo -e "${BOLD}Step 3: Cleaning up any existing AWS VPC CNI resources...${NC}"
kubectl delete configmap amazon-vpc-cni -n kube-system 2>/dev/null || true
kubectl delete serviceaccount aws-node -n kube-system 2>/dev/null || true
kubectl delete clusterrole aws-node 2>/dev/null || true
kubectl delete clusterrolebinding aws-node 2>/dev/null || true

# Step 4: Install the AWS VPC CNI
echo ""
echo -e "${BOLD}Step 4: Installing the AWS VPC CNI...${NC}"
echo "Downloading the AWS VPC CNI manifest..."
curl -s -o aws-k8s-cni.yaml https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/master/aws-k8s-cni.yaml

echo "Applying the AWS VPC CNI manifest..."
kubectl apply -f aws-k8s-cni.yaml
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to apply the AWS VPC CNI manifest.${NC}"
    exit 1
fi
echo -e "${GREEN}AWS VPC CNI manifest applied successfully.${NC}"

# Step 5: Wait for the AWS VPC CNI pods to be ready
echo ""
echo -e "${BOLD}Step 5: Waiting for the AWS VPC CNI pods to be ready...${NC}"
echo "This may take a few minutes..."
kubectl rollout status daemonset aws-node -n kube-system --timeout=300s
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: AWS VPC CNI pods did not become ready within the timeout period.${NC}"
    echo "Checking AWS VPC CNI pod status..."
    kubectl get pods -n kube-system -l k8s-app=aws-node
    echo ""
    echo "Checking AWS VPC CNI pod logs..."
    AWS_NODE_POD=$(kubectl get pods -n kube-system -l k8s-app=aws-node -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$AWS_NODE_POD" ]; then
        kubectl logs $AWS_NODE_POD -n kube-system
    else
        echo "No AWS VPC CNI pod found."
    fi
    exit 1
fi
echo -e "${GREEN}AWS VPC CNI pods are ready.${NC}"

# Step 6: Check if the Redis Enterprise Operator pod is now running
echo ""
echo -e "${BOLD}Step 6: Checking if the Redis Enterprise Operator pod is now running...${NC}"
kubectl get pods -n rec-large-scale -l name=redis-enterprise-operator
echo ""
echo "If the Redis Enterprise Operator pod is still not running, you may need to delete and recreate it:"
echo "kubectl delete pod -n rec-large-scale -l name=redis-enterprise-operator"

echo ""
echo -e "${BOLD}=== AWS VPC CNI Fix Complete ===${NC}"
echo ""
echo "If the Redis Enterprise Operator is still not working, please check the following:"
echo "1. Make sure the AWS VPC CNI pods are running"
echo "2. Make sure the Redis Enterprise Operator pod is running"
echo "3. Check the Redis Enterprise Operator pod logs for any errors"
echo "4. Make sure the Redis Enterprise Cluster custom resource is correctly defined"
echo ""
echo "For more information, see the Redis Enterprise Kubernetes documentation:"
echo "https://docs.redis.com/latest/kubernetes/"
