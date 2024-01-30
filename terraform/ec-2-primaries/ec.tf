resource "aws_elasticache_replication_group" "ec_2_primaries" {
  replication_group_id       = "ec-02-primaries"
  description                = "EC 2 primaries"
  node_type                  = "cache.m6g.8xlarge"
  port                       = 6379
  apply_immediately          = true
  parameter_group_name       = "default.redis7.cluster.on"
  automatic_failover_enabled = true
  multi_az_enabled           = true

  num_node_groups            = 2
  replicas_per_node_group    = 2
  security_group_ids         = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  subnet_group_name          = "ec-multi-az"
  transit_encryption_enabled = false
  # auth_token = "performance-at-redis"
}
