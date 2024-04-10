
module "memory_db" {
  source = "terraform-aws-modules/memory-db/aws"

  # Cluster
  name        = "vecsim"
  description = "vecsim single shard 2xlarge"

  engine_version             = "7.1"
  auto_minor_version_upgrade = true
  node_type                  = "db.r7g.2xlarge"
  num_shards                 = 1
  num_replicas_per_shard     = 0
  security_group_ids         = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]

  tls_enabled = false

  # Parameter group
  create_parameter_group = false
  parameter_group_family = "default.memorydb-redis7.search.preview"
  parameter_group_name   = "default.memorydb-redis7.search.preview"

  # ACL
  create_acl = false
  acl_name   = "open-access"

  # Subnet group
  subnet_ids = ["subnet-0597ccd9e8d2a050e"]

  tags = {
    Project = "Vecsim-MemoryDB"
  }
}
