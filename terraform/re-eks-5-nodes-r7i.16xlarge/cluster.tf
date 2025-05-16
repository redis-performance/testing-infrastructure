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

  instance_types = ["r7i.16xlarge"]
  disk_size      = 1024
  ami_type       = "AL2_x86_64"
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
if kubectl -n kube-system get daemonset aws-node >/dev/null 2>&1; then
  echo "Deleting aws-node DaemonSet..."
  kubectl -n kube-system delete daemonset aws-node
else
  echo "DaemonSet aws-node already deleted or does not exist."
fi
EOT
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "null_resource" "patch_vpc_cni_resources" {
  provisioner "local-exec" {
    command = <<EOT
set -e

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
EOT
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "helm_release" "aws_vpc_cni" {
  depends_on = [
    aws_eks_cluster.main,
    null_resource.update_kubeconfig,
    null_resource.patch_vpc_cni_resources,
    null_resource.delete_aws_node_ds
  ]

  name       = "aws-vpc-cni"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-vpc-cni"

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
}