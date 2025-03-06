# resource "aws_elasticache_cluster" "ec" {
#   cluster_id           = "ec-1-primaries-v8-r7g-xlarge"
#   node_type            = "cache.m7g.xlarge"
#   port                 = 6379
#   apply_immediately    = true
#   parameter_group_name = "default.valkey8"
#   engine               = "valkey"
#   num_cache_nodes      = 1
#   security_group_ids   = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
#   subnet_group_name    = "ec-subnet"
#   availability_zone    = "us-east-2a"
# }

resource "aws_elasticache_replication_group" "ec" {
  automatic_failover_enabled  = false
  preferred_cache_cluster_azs = ["us-east-2a"]
  replication_group_id        = "ec-1-primaries-v8-r7g-large"
  description                 = "xlarge cache"
  node_type                   = "cache.m7g.large"
  num_cache_clusters          = 1
  parameter_group_name        = "default.valkey8"
  engine                      = "valkey"
  port                        = 6379
  security_group_ids          = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  subnet_group_name           = "ec-subnet"
  at_rest_encryption_enabled  = false
  data_tiering_enabled        = false
}


