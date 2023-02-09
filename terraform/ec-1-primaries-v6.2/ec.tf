resource "aws_elasticache_cluster" "ec" {
  cluster_id           = "ec-01-primaries-redis6x"
  node_type            = "cache.m6g.12xlarge"
  port                 = 6379
  apply_immediately    = true
  parameter_group_name = "default.redis6.x"
  engine               = "redis"
  engine_version       = "6.x"
  availability_zone    = "us-east-2a"
  num_cache_nodes      = 1
  security_group_ids   = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  subnet_group_name    = "ec-multi-az"
}
