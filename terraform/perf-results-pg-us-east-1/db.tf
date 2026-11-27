resource "aws_db_subnet_group" "db" {
  name       = local.name
  subnet_ids = data.aws_subnets.default.ids
  tags       = local.tags
}

resource "aws_db_parameter_group" "db" {
  name   = local.name
  family = var.parameter_group_family
  tags   = local.tags

  # TLS only (the IAM authentication token travels as the password).
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  # Connections and slow statements in the log, for the odd runaway query from an MCP client. PostgreSQL 18
  # takes a list of connection stages here; these three are what "on" meant before.
  parameter {
    name  = "log_connections"
    value = "receipt,authentication,authorization"
  }
  parameter {
    name  = "log_min_duration_statement"
    value = "5000"
  }
}

resource "aws_db_instance" "db" {
  identifier     = local.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "results"
  username = "dbadmin"
  # The master password lives in Secrets Manager (rotated by RDS), never in this state or the repo. Day to
  # day, clients connect with IAM authentication tokens as the reader or writer roles (README).
  manage_master_user_password         = true
  iam_database_authentication_enabled = true

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.db.name
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period    = var.backup_retention_days
  backup_window              = "06:00-06:30"
  maintenance_window         = "sun:07:00-sun:07:30"
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  deletion_protection        = true
  skip_final_snapshot        = false
  final_snapshot_identifier  = "${local.name}-final"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = local.tags

  lifecycle {
    prevent_destroy = true
  }
}
