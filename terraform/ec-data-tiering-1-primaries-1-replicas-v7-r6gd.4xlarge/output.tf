
output "primary_endpoint_address" {
  value = ["${aws_elasticache_replication_group.rg.primary_endpoint_address}"]
}
