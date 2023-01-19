output "ec_ip" {
  value = ["${aws_elasticache_replication_group.ec.configuration_endpoint_address}"]
}

output "ec_members" {
  value = ["${aws_elasticache_replication_group.ec.member_clusters}"]
}
