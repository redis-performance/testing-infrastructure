resource "aws_elasticache_replication_group" "ec" {
  replication_group_id       = "ec-04-primaries"
  description                = "EC 4 primaries"
  node_type                  = "cache.m6g.4xlarge"
  port                       = 6379
  apply_immediately          = true
  parameter_group_name       = "default.redis7.cluster.on"
  automatic_failover_enabled = true
  multi_az_enabled           = true

  num_node_groups            = 4
  replicas_per_node_group    = 2
  security_group_ids         = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  subnet_group_name          = "ec-multi-az"
  transit_encryption_enabled = false
}
