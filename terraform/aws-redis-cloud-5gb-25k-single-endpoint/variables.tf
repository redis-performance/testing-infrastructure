################################################################################
# Variables used for deployment tag
################################################################################

variable "db_name" {
  description = "db name"
  default     = "perf-5GB-25K-single-endpoint-db"
}

variable "subscription_name" {
  description = "db name"
  default     = "perf-5GB-25K-single-endpoint-db"
}


variable "ops_sec" {
  description = "db name"
  default     = 25000
}

variable "memory_limit_in_gb" {
  description = "memory_limit_in_gb"
  default     = 5
}

variable "replication" {
  description = "replication"
  default     = true
}

variable "support_oss_cluster_api" {
  description = "support_oss_cluster_api"
  default     = false
}
