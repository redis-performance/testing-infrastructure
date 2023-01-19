output "ec_ip" {
  value = ["${aws_elasticache_replication_group.ec_2_primaries.configuration_endpoint_address}"]
}

output "ec_members" {
  value = ["${aws_elasticache_replication_group.ec_2_primaries.member_clusters}"]
}
