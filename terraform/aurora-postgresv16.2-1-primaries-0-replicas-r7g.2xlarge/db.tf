
module "cluster" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name           = "vector-benchmark-aurora-db-postgres-16-2"
  engine         = "aurora-postgresql"
  engine_version = "16.2"
  instance_class = "db.r7g.large"
  instances = {
    one = {
      instance_class = "db.r7g.2xlarge"
    }
  }
  manage_master_user_password = false
  master_password             = "performance"
  master_username             = "postgres"

  vpc_id               = data.terraform_remote_state.shared_resources.outputs.performance_cto_vpc_id
  db_subnet_group_name = "perf-cto-us-east-2-documentdb-subnetgroup"

  security_group_rules = {
    ex1_ingress = {
      cidr_blocks = ["10.20.0.0/20"]
    }
    ex1_ingress = {
      source_security_group_id = "${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"
    }
  }

  storage_encrypted   = true
  apply_immediately   = true
  monitoring_interval = 10
  skip_final_snapshot = true

  tags = {
    "Name"  = "vector-benchmark-aurora-db-postgres-16-2"
    Project = "Vector-Competitive-Aurora"
  }
}
