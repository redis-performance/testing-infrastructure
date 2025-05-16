output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "node_group_name" {
  value = aws_eks_node_group.r7i_nodes.node_group_name
}
