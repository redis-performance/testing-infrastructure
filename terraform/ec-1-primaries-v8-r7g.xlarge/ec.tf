
resource "aws_elasticache_replication_group" "ec" {
  automatic_failover_enabled  = false
  preferred_cache_cluster_azs = ["us-east-2a"]
  replication_group_id        = "ec-1-primaries-v8-r7g-xlarge"
  description                 = "xlarge cache"
  node_type                   = "cache.r7g.xlarge"
  num_cache_clusters          = 1
  parameter_group_name        = "default.valkey8"
  engine                      = "valkey"
  port                        = 6379
  security_group_ids          = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  subnet_group_name           = "ec-subnet"
  at_rest_encryption_enabled  = false
  data_tiering_enabled        = false
  apply_immediately           = true
}


