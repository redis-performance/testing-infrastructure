#!/bin/bash
#
# troubleshoot-operator.sh - Troubleshoot Redis Enterprise Operator issues
#
# This script helps diagnose and fix issues with the Redis Enterprise Operator.
#


# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== Redis Enterprise Operator Troubleshooting ===${NC}"
echo ""

# Step 1: Check AWS credentials
echo -e "${BOLD}Step 1: Checking AWS credentials...${NC}"
AWS_IDENTITY=$(aws sts get-caller-identity 2>&1)
if [[ $AWS_IDENTITY == *"ExpiredToken"* ]]; then
    echo -e "${RED}Error: AWS credentials have expired.${NC}"
    echo "Please refresh your AWS credentials and try again."
    echo "You can refresh your credentials by running:"
    echo "  aws sso login"
    echo "or by setting the AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN environment variables."
    exit 1
elif [[ $AWS_IDENTITY == *"Unable to locate credentials"* ]]; then
    echo -e "${RED}Error: AWS credentials not found.${NC}"
    echo "Please configure your AWS credentials and try again."
    echo "You can configure your credentials by running:"
    echo "  aws configure"
    exit 1
else
    echo -e "${GREEN}AWS credentials are valid.${NC}"
    echo "$AWS_IDENTITY"
fi

# Step 2: Update kubeconfig
echo ""
echo -e "${BOLD}Step 2: Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region us-east-2 --name re-eks-cluster-5-nodes-r7i-16xlarge
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to update kubeconfig.${NC}"
    echo "Please check if the EKS cluster exists and you have the correct permissions."
    exit 1
fi
echo -e "${GREEN}Kubeconfig updated successfully.${NC}"

# Step 3: Check if the namespace exists
echo ""
echo -e "${BOLD}Step 3: Checking if the namespace exists...${NC}"
NAMESPACE="rec-large-scale"
if ! kubectl get namespace $NAMESPACE &>/dev/null; then
    echo -e "${YELLOW}Namespace $NAMESPACE does not exist. Creating it...${NC}"
    kubectl create namespace $NAMESPACE
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create namespace $NAMESPACE.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Namespace $NAMESPACE created successfully.${NC}"
else
    echo -e "${GREEN}Namespace $NAMESPACE exists.${NC}"
fi

# Step 4: Set the current context to the namespace
echo ""
echo -e "${BOLD}Step 4: Setting the current context to the namespace...${NC}"
kubectl config set-context --current --namespace=$NAMESPACE
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to set the current context to namespace $NAMESPACE.${NC}"
    exit 1
fi
echo -e "${GREEN}Current context set to namespace $NAMESPACE.${NC}"

# Step 5: Check if the operator is deployed
echo ""
echo -e "${BOLD}Step 5: Checking if the operator is deployed...${NC}"
if ! kubectl get deployment redis-enterprise-operator &>/dev/null; then
    echo -e "${YELLOW}Operator is not deployed. Deploying it...${NC}"

    # Deploy the operator
    VERSION="7.22.0-7"
    echo "Deploying Redis Enterprise Operator version $VERSION..."
    kubectl apply -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/$VERSION/bundle.yaml
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to deploy the operator.${NC}"
        exit 1
    fi

    # Wait for the operator to be ready
    echo "Waiting for the operator to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/redis-enterprise-operator
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Operator deployment did not become ready within the timeout period.${NC}"
        echo "Checking operator pod status..."
        kubectl get pods -l name=redis-enterprise-operator
        echo ""
        echo "Checking operator pod logs..."
        OPERATOR_POD=$(kubectl get pods -l name=redis-enterprise-operator -o jsonpath='{.items[0].metadata.name}')
        if [ -n "$OPERATOR_POD" ]; then
            kubectl logs $OPERATOR_POD
        else
            echo "No operator pod found."
        fi
        exit 1
    fi

    echo -e "${GREEN}Operator deployed successfully.${NC}"
else
    echo -e "${GREEN}Operator is already deployed.${NC}"
fi

# Step 6: Check operator status
echo ""
echo -e "${BOLD}Step 6: Checking operator status...${NC}"
kubectl get deployment redis-enterprise-operator -o wide
echo ""
kubectl get pods -l name=redis-enterprise-operator

# Step 7: Check operator logs
echo ""
echo -e "${BOLD}Step 7: Checking operator logs...${NC}"
OPERATOR_POD=$(kubectl get pods -l name=redis-enterprise-operator -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$OPERATOR_POD" ]; then
    kubectl logs $OPERATOR_POD | tail -20
else
    echo -e "${RED}Error: No operator pod found.${NC}"
fi

# Step 8: Check if Redis Enterprise Cluster is deployed
echo ""
echo -e "${BOLD}Step 8: Checking if Redis Enterprise Cluster is deployed...${NC}"
if ! kubectl get rec &>/dev/null; then
    echo -e "${YELLOW}Redis Enterprise Cluster is not deployed.${NC}"
    echo "You can deploy it by creating a REC custom resource."
    echo "Example:"
    echo "  kubectl apply -f cluster.yaml"
else
    echo -e "${GREEN}Redis Enterprise Cluster is deployed.${NC}"
    kubectl get rec
fi

# Step 9: Check Redis Enterprise Cluster status
echo ""
echo -e "${BOLD}Step 9: Checking Redis Enterprise Cluster status...${NC}"
if kubectl get rec &>/dev/null; then
    REC_NAME=$(kubectl get rec -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$REC_NAME" ]; then
        echo "Redis Enterprise Cluster name: $REC_NAME"
        kubectl get rec $REC_NAME -o yaml | grep -A 5 "status:"

        # Check Redis Enterprise Cluster pods
        echo ""
        echo "Redis Enterprise Cluster pods:"
        kubectl get pods -l redis.io/cluster=$REC_NAME
    else
        echo "No Redis Enterprise Cluster found."
    fi
else
    echo "No Redis Enterprise Cluster found."
fi

# Step 10: Check Redis Enterprise Database status
echo ""
echo -e "${BOLD}Step 10: Checking Redis Enterprise Database status...${NC}"
if kubectl get redb &>/dev/null; then
    echo "Redis Enterprise Databases:"
    kubectl get redb
else
    echo "No Redis Enterprise Databases found."
fi

echo ""
echo -e "${BOLD}=== Troubleshooting Complete ===${NC}"
echo ""
echo "If the operator is still not working, please check the following:"
echo "1. Make sure your AWS credentials are valid"
echo "2. Make sure the EKS cluster is running"
echo "3. Make sure the operator has the necessary permissions"
echo "4. Check the operator logs for any errors"
echo "5. Make sure the Redis Enterprise Cluster custom resource is correctly defined"
echo ""
echo "For more information, see the Redis Enterprise Kubernetes documentation:"
echo "https://docs.redis.com/latest/kubernetes/"
