#!/bin/bash
#
# fix-ebs-csi-auth.sh - Fix AWS EBS CSI Driver authentication issues
#
# This script creates an IAM role with the necessary permissions for the EBS CSI Driver,
# annotates the EBS CSI Driver service account with the IAM role ARN, and restarts the
# EBS CSI Driver pods.
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== Fixing AWS EBS CSI Driver Authentication Issues ===${NC}"
echo ""

# Step 1: Get the OIDC provider URL for the EKS cluster
echo -e "${BOLD}Step 1: Getting the OIDC provider URL for the EKS cluster...${NC}"
CLUSTER_NAME="re-eks-cluster-5-nodes-r7i-16xlarge"
OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

if [ -z "$OIDC_PROVIDER" ]; then
    echo -e "${RED}Error: Failed to get the OIDC provider URL for the EKS cluster.${NC}"
    echo "Please check if the EKS cluster exists and you have the correct permissions."
    exit 1
fi

echo "OIDC provider URL: $OIDC_PROVIDER"

# Step 2: Create an IAM policy for the EBS CSI Driver
echo ""
echo -e "${BOLD}Step 2: Creating an IAM policy for the EBS CSI Driver...${NC}"
POLICY_NAME="AmazonEKS_EBS_CSI_Driver_Policy"
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
    echo "Creating IAM policy $POLICY_NAME..."
    POLICY_ARN=$(aws iam create-policy --policy-name $POLICY_NAME --policy-document file://ebs-csi-policy.json --query "Policy.Arn" --output text)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create IAM policy $POLICY_NAME.${NC}"
        exit 1
    fi
    echo -e "${GREEN}IAM policy $POLICY_NAME created successfully.${NC}"
else
    echo -e "${GREEN}IAM policy $POLICY_NAME already exists.${NC}"
fi

echo "Policy ARN: $POLICY_ARN"

# Step 3: Create an IAM role for the EBS CSI Driver
echo ""
echo -e "${BOLD}Step 3: Creating an IAM role for the EBS CSI Driver...${NC}"
ROLE_NAME="AmazonEKS_EBS_CSI_DriverRole"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Create a trust policy document
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF

# Check if the role already exists
ROLE_ARN=$(aws iam list-roles --query "Roles[?RoleName=='$ROLE_NAME'].Arn" --output text)

if [ -z "$ROLE_ARN" ]; then
    echo "Creating IAM role $ROLE_NAME..."
    ROLE_ARN=$(aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json --query "Role.Arn" --output text)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to create IAM role $ROLE_NAME.${NC}"
        exit 1
    fi
    echo -e "${GREEN}IAM role $ROLE_NAME created successfully.${NC}"
else
    echo -e "${GREEN}IAM role $ROLE_NAME already exists.${NC}"
fi

echo "Role ARN: $ROLE_ARN"

# Step 4: Attach the IAM policy to the IAM role
echo ""
echo -e "${BOLD}Step 4: Attaching the IAM policy to the IAM role...${NC}"
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to attach IAM policy $POLICY_NAME to IAM role $ROLE_NAME.${NC}"
    exit 1
fi
echo -e "${GREEN}IAM policy $POLICY_NAME attached to IAM role $ROLE_NAME successfully.${NC}"

# Step 5: Annotate the EBS CSI Driver service account with the IAM role ARN
echo ""
echo -e "${BOLD}Step 5: Annotating the EBS CSI Driver service account with the IAM role ARN...${NC}"
kubectl annotate serviceaccount -n kube-system ebs-csi-controller-sa eks.amazonaws.com/role-arn=$ROLE_ARN --overwrite
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to annotate the EBS CSI Driver service account with the IAM role ARN.${NC}"
    exit 1
fi
echo -e "${GREEN}EBS CSI Driver service account annotated with the IAM role ARN successfully.${NC}"

# Step 6: Restart the EBS CSI Driver pods
echo ""
echo -e "${BOLD}Step 6: Restarting the EBS CSI Driver pods...${NC}"
kubectl delete pods -n kube-system -l app=ebs-csi-controller
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to restart the EBS CSI Driver pods.${NC}"
    exit 1
fi
echo -e "${GREEN}EBS CSI Driver pods restarted successfully.${NC}"

# Step 7: Wait for the EBS CSI Driver pods to be ready
echo ""
echo -e "${BOLD}Step 7: Waiting for the EBS CSI Driver pods to be ready...${NC}"
echo "This may take a few minutes..."
kubectl wait --for=condition=ready pods -n kube-system -l app=ebs-csi-controller --timeout=300s
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: EBS CSI Driver pods did not become ready within the timeout period.${NC}"
    echo "Checking EBS CSI Driver pod status..."
    kubectl get pods -n kube-system -l app=ebs-csi-controller
    exit 1
fi
echo -e "${GREEN}EBS CSI Driver pods are ready.${NC}"

# Step 8: Check if the persistent volume claims are now being provisioned
echo ""
echo -e "${BOLD}Step 8: Checking if the persistent volume claims are now being provisioned...${NC}"
echo "This may take a few minutes..."
kubectl get pvc -n rec-large-scale
echo ""
echo "If the persistent volume claims are still in the 'Pending' state, you may need to delete and recreate them:"
echo "kubectl delete pvc -n rec-large-scale --all"
echo ""
echo "Then, delete and recreate the Redis Enterprise Cluster:"
echo "kubectl delete rec -n rec-large-scale rec-large-scale-5nodes"
echo "kubectl apply -f cluster.yaml"

echo ""
echo -e "${BOLD}=== AWS EBS CSI Driver Authentication Fix Complete ===${NC}"
echo ""
echo "If the Redis Enterprise Cluster pods are still not running, please check the following:"
echo "1. Make sure the EBS CSI Driver pods are running"
echo "2. Make sure the persistent volume claims are being provisioned"
echo "3. Make sure the Redis Enterprise Cluster pods are being scheduled"
echo "4. Check the Redis Enterprise Cluster pod logs for any errors"
echo ""
echo "For more information, see the Redis Enterprise Kubernetes documentation:"
echo "https://docs.redis.com/latest/kubernetes/"
