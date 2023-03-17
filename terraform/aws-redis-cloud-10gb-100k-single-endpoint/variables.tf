################################################################################
# Variables used for deployment tag
################################################################################

variable "db_name" {
  description = "db name"
  default     = "MASTODON-10GB-100K-single-endpoint-db"
}

variable "subscription_name" {
  description = "db name"
  default     = "MASTODON-10GB-100K-single-endpoint"
}


variable "ops_sec" {
  description = "db name"
  default     = 100000
}

variable "memory_limit_in_gb" {
  description = "memory_limit_in_gb"
  default     = 10
}

variable "replication" {
  description = "replication"
  default     = true
}

variable "support_oss_cluster_api" {
  description = "support_oss_cluster_api"
  default     = false
}
