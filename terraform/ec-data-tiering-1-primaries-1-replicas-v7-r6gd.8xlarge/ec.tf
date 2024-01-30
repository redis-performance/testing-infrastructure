
resource "aws_elasticache_replication_group" "rg" {

  # The replication group identifier. This parameter is stored as a lowercase string.
  #
  # - Must contain from 1 to 20 alphanumeric characters or hyphens.
  # - Must begin with a letter.
  # - Cannot contain two consecutive hyphens.
  # - Cannot end with a hyphen.
  #
  # https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/Clusters.Create.CON.Redis.html
  replication_group_id = "ec-data-tiering-r6gd-8xlarge"
  node_type            = "cache.r6gd.8xlarge"
  port                 = 6379
  apply_immediately    = true
  parameter_group_name = "default.redis7"
  engine               = "redis"
  # The number of clusters this replication group initially has.
  # If automatic_failover_enabled is true, the value of this parameter must be at least 2.
  # The maximum permitted value for number_cache_clusters is 6 (1 primary plus 5 replicas).
  # https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/Scaling.RedisReplGrps.html
  replicas_per_node_group = 1
  security_group_ids      = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  subnet_group_name       = "ec-subnet"
  data_tiering_enabled    = true

  # A user-created description for the replication group.
  description = "ec-data-tiering-r6gd-8xlarge"

}
