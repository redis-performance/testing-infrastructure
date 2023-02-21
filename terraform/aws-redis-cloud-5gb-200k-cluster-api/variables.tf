################################################################################
# Variables used for deployment tag
################################################################################

variable "db_name" {
  description = "db name"
  default     = "perf-5GB-200K-cluster-api-db"
}

variable "subscription_name" {
  description = "db name"
  default     = "perf-5GB-200K-cluster-api"
}


variable "ops_sec" {
  description = "db name"
  default     = 200000
}
