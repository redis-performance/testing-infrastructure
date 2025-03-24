
output "ec_members" {
  value = ["${aws_elasticache_replication_group.ec}"]
  sensitive = true
}

