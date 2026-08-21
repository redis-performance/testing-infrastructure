resource "aws_elasticache_replication_group" "ec" {
  replication_group_id       = "ec-120-primaries-v7-r7g-large"
  description                = "ec-120-primaries-v7-r7g-large"
  node_type                  = "cache.r7g.large"
  port                       = 6379
  apply_immediately          = true
  parameter_group_name       = "default.valkey7.cluster.on"
  automatic_failover_enabled = true
  multi_az_enabled           = false
  engine                     = "valkey"
  engine_version             = "7.2"

  # You can specify subnet_group_name to control the availability zones if your Replication Group is in a VPC.
  subnet_group_name = "ec-subnet"

  num_node_groups            = 90
  replicas_per_node_group    = 0
  security_group_ids         = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  transit_encryption_enabled = false
  tags = {
    team = "performance_analysis_optimization"
  }
}
