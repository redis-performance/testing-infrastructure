module "cluster" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name           = "topdown-perf-analysis-db"
  engine         = "aurora-postgresql"
  engine_version = "16.4"

  instances = {
    one = {
      instance_class      = "db.t4g.medium"
      monitoring_interval = 10
      publicly_accessible = true
    }
  }

  manage_master_user_password = false
  master_password_wo          = "G3Oz1IKNYZWu9KvS9BqBKR8i"
  master_password_wo_version  = 1
  master_username             = "postgres"

  vpc_id               = data.terraform_remote_state.us_east_1_common.outputs.perf_cto_vpc_id
  db_subnet_group_name = data.terraform_remote_state.us_east_1_common.outputs.db_subnet_group_name

  security_group_ingress_rules = {
    vpc_ingress = {
      cidr_ipv4   = "10.4.0.0/16"
      from_port   = 5432
      to_port     = 5432
      ip_protocol = "tcp"
      description = "PostgreSQL from VPC"
    }
    internal_ingress = {
      cidr_ipv4   = "10.0.0.0/8"
      from_port   = 5432
      to_port     = 5432
      ip_protocol = "tcp"
      description = "PostgreSQL from internal"
    }
    sg_ingress = {
      referenced_security_group_id = data.terraform_remote_state.us_east_1_common.outputs.perf_cto_sg_id
      from_port                    = 5432
      to_port                      = 5432
      ip_protocol                  = "tcp"
      description                  = "PostgreSQL from perf-cto SG"
    }
    public_ingress = {
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 5432
      to_port     = 5432
      ip_protocol = "tcp"
      description = "PostgreSQL public access"
    }
  }

  storage_encrypted   = true
  apply_immediately   = true
  skip_final_snapshot = true

  create_monitoring_role      = true
  cluster_monitoring_interval = 10

  tags = {
    "Name"  = "topdown-perf-analysis-db"
    Project = "topdown-perf-analysis"
    team    = "performance_analysis_optimization"
    owner   = "${var.github_actor}"
  }
}
