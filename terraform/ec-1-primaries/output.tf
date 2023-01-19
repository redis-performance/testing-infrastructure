
output "ec_members" {
  value = ["${aws_elasticache_cluster.ec.cache_nodes}"]
}
