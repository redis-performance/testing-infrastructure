# === Your existing EKS cluster and node group definitions ===
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [
      data.terraform_remote_state.shared_resources.outputs.subnet_us_east_2a_public_id,
      data.terraform_remote_state.shared_resources.outputs.subnet_us_east_2b_public_id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy]
}

resource "aws_launch_template" "r7i_nodes" {
  name_prefix   = "${var.cluster_name}-r7i-nodes-"
  instance_type = "r7i.16xlarge"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 1024
      volume_type = "gp3"
      delete_on_termination = true
    }
  }

  # Add tags to the instances
  tag_specifications {
    resource_type = "instance"

    tags = {
      Project = "k8s"
      Name    = "${var.cluster_name}-node" # Generic name
    }
  }

  # Set up node with Project=k8s label and custom naming pattern
  # Use MIME multi-part format for user data
  user_data = base64encode(<<-EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
set -o xtrace

# Get instance ID and extract the last part for a shorter name
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_SHORT_ID=$(echo $INSTANCE_ID | cut -d '-' -f2 | cut -c 1-8)

# Create a node name with k8s prefix
NODE_NAME="k8s-$INSTANCE_SHORT_ID"

# Set the hostname
hostnamectl set-hostname "$NODE_NAME"

# Install necessary packages for AL2023
dnf update -y
dnf install -y amazon-ssm-agent

# Start and enable SSM agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Bootstrap the node with the Project=k8s label and custom hostname
# AL2023 uses a different bootstrap script location
/usr/bin/bootstrap.sh ${aws_eks_cluster.main.name} --kubelet-extra-args "--node-labels=Project=k8s,Name=$NODE_NAME --hostname-override=$NODE_NAME"

--==MYBOUNDARY==--
  EOF
  )
}

resource "aws_eks_node_group" "r7i_nodes" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-r7i-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = [data.terraform_remote_state.shared_resources.outputs.subnet_us_east_2a_public_id]

  scaling_config {
    desired_size = 5
    max_size     = 5
    min_size     = 5
  }

  # Use launch template instead of direct instance configuration
  launch_template {
    id      = aws_launch_template.r7i_nodes.id
    version = aws_launch_template.r7i_nodes.latest_version
  }

  # Add labels directly to the node group
  labels = {
    "Project" = "k8s"
  }

  # Required for EKS managed node groups
  capacity_type = "ON_DEMAND"

  # These are required even though they're in the launch template
  # They're used to determine the AMI type
  ami_type       = "AL2023_x86_64_STANDARD"

  # Ensure proper node group updates
  update_config {
    max_unavailable = 1
  }

  # Ignore changes to desired_size as it might be modified outside of Terraform
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# === EKS cluster role ===
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# === Node group role ===
resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0afd9e00e"]
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# No additional policies needed

# === EKS Cluster Data Source ===
data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.main.name
}

# === IAM Role and Policy for AWS EBS CSI Driver ===
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${aws_eks_cluster.main.endpoint}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_role" {
  name               = "${var.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attach" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# === Kubernetes Service Account for EBS CSI Driver ===
resource "kubernetes_service_account" "ebs_csi_sa" {
  metadata {
    name      = "ebs-csi-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi_role.arn
    }
  }
}

# === Install EBS CSI Driver Helm Chart ===
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config" # or your cluster config method
  }
}

resource "helm_release" "aws_ebs_csi_driver" {
  depends_on = [
    null_resource.update_kubeconfig,
    kubernetes_service_account.ebs_csi_sa,
    aws_iam_role_policy_attachment.ebs_csi_policy_attach,
  ]

  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.20.0"
  namespace  = "kube-system"

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account.ebs_csi_sa.metadata[0].name
  }

}

# === StorageClass for EBS Volumes ===
resource "kubernetes_storage_class" "ebs_sc" {
  metadata {
    name = "ebs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  reclaim_policy      = "Retain"

  parameters = {
    type = "gp3"
  }
}

provider "kubernetes" {
  host = aws_eks_cluster.main.endpoint

  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", aws_eks_cluster.main.name,
      "--region", var.aws_region,
    ]
  }
}

resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
  }

  triggers = {
    cluster_endpoint = aws_eks_cluster.main.endpoint
  }

  depends_on = [aws_eks_cluster.main]
}

resource "null_resource" "delete_aws_node_ds" {
  provisioner "local-exec" {
    command = <<EOT
# Wait for the cluster to be fully available
echo "Waiting for the cluster to be fully available..."
kubectl wait --for=condition=available --timeout=300s deployment/coredns -n kube-system || true

# Delete the aws-node DaemonSet if it exists
if kubectl -n kube-system get daemonset aws-node >/dev/null 2>&1; then
  echo "Deleting aws-node DaemonSet..."
  kubectl -n kube-system delete daemonset aws-node
else
  echo "DaemonSet aws-node already deleted or does not exist."
fi

# Delete the amazon-vpc-cni ConfigMap if it exists
if kubectl -n kube-system get configmap amazon-vpc-cni >/dev/null 2>&1; then
  echo "Deleting amazon-vpc-cni ConfigMap..."
  kubectl -n kube-system delete configmap amazon-vpc-cni
else
  echo "ConfigMap amazon-vpc-cni already deleted or does not exist."
fi

# Delete other VPC CNI resources that might cause conflicts
for resource in "clusterrole/aws-node" "clusterrolebinding/aws-node" "serviceaccount/aws-node -n kube-system"; do
  if kubectl get $resource >/dev/null 2>&1; then
    echo "Deleting $resource..."
    kubectl delete $resource
  else
    echo "$resource already deleted or does not exist."
  fi
done
EOT
  }

  triggers = {
    always_run = "${timestamp()}"
  }

  depends_on = [
    aws_eks_cluster.main,
    null_resource.update_kubeconfig
  ]
}

resource "null_resource" "patch_vpc_cni_resources" {
  provisioner "local-exec" {
    command = <<EOT
set -e

# Wait for the cluster to be fully available
echo "Waiting for the cluster to be fully available..."
kubectl wait --for=condition=available --timeout=300s deployment/coredns -n kube-system || true

# Check and patch ConfigMap
if kubectl -n kube-system get configmap amazon-vpc-cni >/dev/null 2>&1; then
  echo "Patching ConfigMap..."
  kubectl -n kube-system annotate configmap amazon-vpc-cni \
    meta.helm.sh/release-name=aws-vpc-cni \
    meta.helm.sh/release-namespace=kube-system --overwrite
  kubectl -n kube-system label configmap amazon-vpc-cni \
    app.kubernetes.io/managed-by=Helm --overwrite
else
  echo "ConfigMap amazon-vpc-cni not found. Skipping."
fi

# Check and patch ClusterRole
if kubectl get clusterrole aws-node >/dev/null 2>&1; then
  echo "Patching ClusterRole..."
  kubectl annotate clusterrole aws-node \
    meta.helm.sh/release-name=aws-vpc-cni \
    meta.helm.sh/release-namespace=kube-system --overwrite
  kubectl label clusterrole aws-node \
    app.kubernetes.io/managed-by=Helm --overwrite
else
  echo "ClusterRole aws-node not found. Skipping."
fi

# Check and patch ClusterRoleBinding
if kubectl get clusterrolebinding aws-node >/dev/null 2>&1; then
  echo "Patching ClusterRoleBinding..."
  kubectl annotate clusterrolebinding aws-node \
    meta.helm.sh/release-name=aws-vpc-cni \
    meta.helm.sh/release-namespace=kube-system --overwrite
  kubectl label clusterrolebinding aws-node \
    app.kubernetes.io/managed-by=Helm --overwrite
else
  echo "ClusterRoleBinding aws-node not found. Skipping."
fi

# Check and patch DaemonSet
if kubectl -n kube-system get daemonset aws-node >/dev/null 2>&1; then
  echo "Patching DaemonSet..."
  kubectl -n kube-system annotate daemonset aws-node \
    meta.helm.sh/release-name=aws-vpc-cni \
    meta.helm.sh/release-namespace=kube-system --overwrite
  kubectl -n kube-system label daemonset aws-node \
    app.kubernetes.io/managed-by=Helm --overwrite
else
  echo "DaemonSet aws-node not found. Skipping."
fi

# If ConfigMap exists but patching failed, try to delete it
if kubectl -n kube-system get configmap amazon-vpc-cni >/dev/null 2>&1; then
  # Check if annotations are properly set
  ANNOTATIONS=$(kubectl -n kube-system get configmap amazon-vpc-cni -o jsonpath='{.metadata.annotations}')
  if [[ "$ANNOTATIONS" != *"meta.helm.sh/release-name"* ]] || [[ "$ANNOTATIONS" != *"meta.helm.sh/release-namespace"* ]]; then
    echo "ConfigMap annotations not properly set. Deleting ConfigMap for recreation..."
    kubectl -n kube-system delete configmap amazon-vpc-cni
  fi
fi
EOT
  }

  triggers = {
    always_run = "${timestamp()}"
  }

  depends_on = [
    aws_eks_cluster.main,
    null_resource.update_kubeconfig,
    aws_eks_node_group.r7i_nodes
  ]
}

resource "helm_release" "aws_vpc_cni" {
  depends_on = [
    aws_eks_cluster.main,
    null_resource.update_kubeconfig,
    null_resource.patch_vpc_cni_resources,
    null_resource.delete_aws_node_ds,
    aws_eks_node_group.r7i_nodes
  ]

  name       = "aws-vpc-cni"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-vpc-cni"
  version    = "1.16.0"  # Specify a version for stability

  # Increase timeout for installation
  timeout    = 600

  # Force resource recreation if needed
  recreate_pods = true

  # Attempt to fix issues automatically
  atomic = true

  # Wait for resources to be ready
  wait = true

  set {
    name  = "enablePrefixDelegation"
    value = "true"
  }

  set {
    name  = "env.ENABLE_PREFIX_DELEGATION"
    value = "true"
  }

  set {
    name  = "env.WARM_PREFIX_TARGET"
    value = "1"
  }

  set {
    name  = "env.WARM_ENI_TARGET"
    value = "10"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-node"
  }

  # Add cleanup on fail to ensure resources are properly cleaned up if installation fails
  set {
    name  = "cleanupOnFail"
    value = "true"
  }

  # Add a lifecycle block to handle failures gracefully
  lifecycle {
    ignore_changes = [
      set,  # Ignore changes to set blocks to prevent unnecessary updates
    ]
  }
}