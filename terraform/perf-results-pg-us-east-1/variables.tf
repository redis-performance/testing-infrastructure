variable "region" {
  default = "us-east-1"
}

variable "setup_name" {
  description = "Name of the database and prefix of its resources (subnet group, security groups, IAM): fixed once applied"
  default     = "perf-results-pg-us-east-1"
}

variable "environment" {
  description = "Cost tag"
  default     = "performance-cto"
}

variable "github_actor" {
  description = "The name of the person or app that initiated the deployment (owner tag). Applied by hand, so it defaults to the owner's account-wide tag value."
  default     = "filipe_oliveira"
}

variable "github_repo" {
  default = "redis-performance/testing-infrastructure"
}

variable "github_sha" {
  default = "N/A"
}

# PostgreSQL 18 (RDS default major, 2026-11-27). Minor upgrades are automatic in the maintenance window.
variable "engine_version" {
  default = "18"
}

variable "parameter_group_family" {
  default = "postgres18"
}

# Results rows and TMA samples are small: about 20 MB per year of benchmark campaigns at today's rate.
variable "instance_class" {
  default = "db.t4g.small"
}

variable "allocated_storage_gb" {
  default = 20
}

variable "max_allocated_storage_gb" {
  description = "Storage autoscaling ceiling"
  default     = 100
}

variable "backup_retention_days" {
  default = 7
}

# Security groups whose instances may open 5432 (IAM authentication is still required): the benchmark VMs
# launched in the default VPC use the CTO team group.
variable "client_security_group_ids" {
  type    = list(string)
  default = ["sg-046d72511dd949d2b"]
}

variable "bastion_instance_type" {
  default = "t4g.nano"
}
