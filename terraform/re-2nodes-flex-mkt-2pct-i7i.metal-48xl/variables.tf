################################################################################
# Redis Enterprise Database variables
################################################################################

variable "rs_arch" {
  description = "arch for rs artifact"
  default     = "amd64"
}


variable "rs_build" {
  description = "build for rs artifact"
  default     = "40429"
}

variable "rs_version" {
  description = "version for rs artifact"
  default     = "100.0.21"
}

# From: https://redislabs.atlassian.net/browse/RED-176461
# default['rlec']['default_dmc_threads'] = {
#   1 => 3,
#   8 => 5,
#   12 => 8,
#   16 => 10,
#   22 => 16,
#   30 => 22,
#   32 => 24,
#   60 => 30,
#   64 => 32,
#   96 => 63,
#   129 => 100
# }
# default['rlec']['default_dmc_threads_rof'] = {.      # Unchanged
#   1 => 3,
#   12 => 4,
#   16 => 5,
#   22 => 7,
#   30 => 10,
#   32 => 10,
#   60 => 18,
#   64 => 20,
#   96 => 32,
#   128 => 32
# }

variable "proxy_threads" {
  description = "proxy threads"
  default     = "32"
}

variable "shard_count" {
  description = "Number of primary shards for the Redis database"
  default     = 60
}

variable "memory_size" {
  description = "Memory size for the Redis database in bytes (disk + RAM). 50TiB total (25TB user data + replication)"
  default     = 54975581388800
}

variable "bigstore" {
  description = "Enable Redis on Flash (ROF) for the database"
  type        = bool
  default     = true
}

variable "bigstore_ram_size" {
  description = "RAM size for bigstore (Redis on Flash) in bytes. 1TiB RAM (2% of memory_size, 512GiB/node)"
  type        = number
  default     = 1099511627776
}

variable "db_port" {
  description = "Port for the Redis database"
  default     = 12000
}

variable "oss_cluster" {
  description = "Enable OSS cluster mode for the Redis database"
  type        = bool
  default     = true
}

variable "replication" {
  description = "Enable replication for the Redis database"
  type        = bool
  default     = true
}

variable "redis_version" {
  description = "Redis version for the database (7.4, 8.0, 8.2, or 8.4)"
  default     = "8.4"
}

variable "shards_placement" {
  description = "Shards placement policy (dense or sparse)"
  default     = "sparse"
}

variable "data_persistence" {
  description = "Data persistence type (aof, snapshot, or disabled)"
  default     = "disabled"
}

################################################################################
# Network tuning variables
################################################################################

variable "tune_network" {
  description = "Apply network tuning"
  type        = bool
  default     = false
}

variable "rx_usecs" {
  description = "Network interface RX interrupt coalescing in microseconds"
  type        = number
  default     = 500
}

variable "tx_usecs" {
  description = "Network interface TX interrupt coalescing in microseconds"
  type        = number
  default     = 500
}

variable "adaptive_rx" {
  description = "Enable adaptive RX interrupt coalescing (on or off)"
  type        = string
  default     = "off"
  validation {
    condition     = contains(["on", "off"], var.adaptive_rx)
    error_message = "adaptive_rx must be either 'on' or 'off'."
  }
}

################################################################################
# TLS/SSL configuration variables
################################################################################

variable "tls_mode" {
  description = "TLS mode for the Redis database (enabled or disabled)"
  type        = string
  default     = "enabled"
  validation {
    condition     = contains(["enabled", "disabled"], var.tls_mode)
    error_message = "tls_mode must be either 'enabled' or 'disabled'."
  }
}

variable "enforce_client_authentication" {
  description = "Enforce client authentication for TLS connections (enabled or disabled)"
  type        = string
  default     = "disabled"
  validation {
    condition     = contains(["enabled", "disabled"], var.enforce_client_authentication)
    error_message = "enforce_client_authentication must be either 'enabled' or 'disabled'."
  }
}

################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "re-2nodes-flex-mkt-2pct-i7i.metal-48xl"
}

variable "github_actor" {
  description = "The name of the person or app that initiated the deployment."
  default     = "N/A"
}

variable "github_repo" {
  description = "	The owner and repository name. For example, testing-infrastructure."
  default     = "N/A"
}

variable "triggering_env" {
  description = "	The triggering environment. For example circleci."
  default     = "N/A"
}

variable "environment" {
  description = "	The cost tag."
  default     = "MKT-FLEX-BENCHMARK"
}

variable "github_org" {
  description = "	The owner name. For example, RedisModules."
  default     = "N/A"
}

variable "github_sha" {
  description = "The commit SHA that triggered the deployment."
  default     = "N/A"
}

variable "timeout_secs" {
  description = "The maximum time to wait prior destroying the VM via the watchdog."
  default     = "3600"
}



################################################################################
# Access keys
################################################################################
variable "private_key" {
  description = "private key"
  default     = "~/redislabs/pems/benchmarksredislabsus-east-1.pem"
}

variable "key_name" {
  description = "key name"
  default     = "benchmarks.redislabs.us-east-1"
}

variable "region" {
  default = "us-east-1"
}

# (Ubuntu 22.04)
# https://cloud-images.ubuntu.com/locator/ec2/
# us-east-1	Jammy Jellyfish	22.04 LTS	amd64	hvm:ebs-ssd	20260320	ami-00de3875b03809ec5	hvm
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-1 Ubuntu 22.04"
  default     = "ami-00de3875b03809ec5" # Ubuntu 22.04 LTS us-east-1
}


variable "instance_device_name" {
  description = "EC2 instance device name"
  default     = "/dev/sda1"
}

variable "redis_module" {
  description = "redis_module"
  default     = "N/A"
}

variable "instance_volume_size" {
  description = "EC2 instance volume_size"
  default     = "2048"
}

variable "instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp3"
}


variable "instance_volume_iops" {
  description = "EC2 instance volume_iops"
  default     = "3000"
}

variable "instance_volume_encrypted" {
  description = "EC2 instance instance_volume_encrypted"
  default     = "false"
}

variable "instance_root_block_device_encrypted" {
  description = "EC2 instance instance_root_block_device_encrypted"
  default     = "false"
}

variable "instance_cpu_threads_per_core" {
  description = "CPU threads per core for aws EC2 instance"
  default     = 1
}

variable "instance_cpu_threads_per_core_hyperthreading" {
  description = "CPU threads per core when hyperthreading is enabled for aws EC2 instance"
  default     = 2
}

variable "instance_network_interface_plus_count" {
  description = "number of additional network interfaces to add to aws EC2 instance"
  default     = 0
}

variable "os" {
  description = "os"
  default     = "ubuntu22.04"
}

variable "ssh_user" {
  description = "ssh_user"
  default     = "ubuntu"
}

################################################################################
# Specific DB machine variables
################################################################################
variable "server_instance_type" {
  description = "type for aws EC2 instance"
  default     = "i7i.metal-48xl"
}

variable "server_instance_count" {
  description = "count of aws EC2 instances"
  default     = 2
}

variable "server_instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 96
}

################################################################################
# Placement group
################################################################################
variable "placement_group" {
  description = "Name of the placement group for this setup"
  default     = "re-2nodes-flex-mkt-2pct-i7i.metal-48xl"
}

################################################################################
# Client machine variables
################################################################################
variable "client_instance_type" {
  description = "type for aws EC2 client instance"
  default     = "i7i.metal-48xl"
}

variable "client_instance_count" {
  description = "count of aws EC2 client instances"
  default     = 2
}

################################################################################
# Cluster name
################################################################################
variable "cluster_name" {
  description = "Redis Enterprise cluster name"
  default     = "re-2nodes-flex-mkt-2pct"
}

variable "rs_username" {
  description = "Redis Enterprise cluster admin user"
  type        = string
}

variable "rs_password" {
  description = "Redis Enterprise cluster admin password"
  type        = string
  sensitive   = true
}

variable "license_file" {
  description = "Path to a valid Redis Enterprise license file (not committed)"
  type        = string
}
