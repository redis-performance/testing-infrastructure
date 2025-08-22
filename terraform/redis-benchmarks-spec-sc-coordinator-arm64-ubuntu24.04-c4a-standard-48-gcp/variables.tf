# Redis Benchmarks Spec SC Coordinator - GCP C4A Variables

################################################################################
# Project and Region Configuration
################################################################################
variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "redislabs-cto"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "deployment_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "redis-benchmark-c4a"
}

variable "environment" {
  description = "Environment name for cost tracking"
  type        = string
  default     = "oss-spec-arm-gcp"
}

################################################################################
# Instance Configuration
################################################################################
variable "instance_name" {
  description = "Name of the compute instance"
  type        = string
  default     = "redis-benchmark-coordinator-c4a"
}

variable "machine_type" {
  description = "GCP C4A machine type"
  type        = string
  default     = "c4a-standard-48"
  validation {
    condition = can(regex("^c4a-(standard|highcpu|highmem)-[0-9]+(-lssd)?$", var.machine_type))
    error_message = "Machine type must be a valid C4A instance type (e.g., c4a-standard-48, c4a-highmem-32, c4a-highcpu-64)."
  }
}

variable "boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 256
}

variable "boot_disk_type" {
  description = "Boot disk type"
  type        = string
  default     = "hyperdisk-balanced"
  validation {
    condition = contains(["hyperdisk-balanced", "hyperdisk-extreme", "hyperdisk-throughput"], var.boot_disk_type)
    error_message = "C4A instances only support Hyperdisk types: hyperdisk-balanced, hyperdisk-extreme, hyperdisk-throughput."
  }
}

variable "additional_disk_size" {
  description = "Additional disk size in GB (0 to disable)"
  type        = number
  default     = 0
}

variable "disk_type" {
  description = "Additional disk type"
  type        = string
  default     = "hyperdisk-balanced"
}

################################################################################
# Networking Configuration
################################################################################
variable "create_network" {
  description = "Whether to create a new VPC network"
  type        = bool
  default     = true
}

variable "network_name" {
  description = "Name of existing network (if create_network is false)"
  type        = string
  default     = "default"
}

variable "subnetwork_name" {
  description = "Name of existing subnetwork (if create_network is false)"
  type        = string
  default     = ""
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "create_external_ip" {
  description = "Whether to create and assign an external IP"
  type        = bool
  default     = true
}

variable "allowed_source_ranges" {
  description = "Source IP ranges allowed to access the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_tier1_networking" {
  description = "Enable Tier 1 networking for higher bandwidth (up to 100 Gbps)"
  type        = bool
  default     = true
}

################################################################################
# SSH Configuration
################################################################################
variable "ssh_user" {
  description = "SSH username"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string
  default     = ""
}

################################################################################
# Service Account Configuration
################################################################################
variable "service_account_email" {
  description = "Service account email for the instance"
  type        = string
  default     = ""
}

variable "service_account_scopes" {
  description = "Service account scopes"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write"
  ]
}

################################################################################
# Benchmark Coordinator Configuration
################################################################################
variable "platform_name" {
  description = "Platform name for the benchmark coordinator"
  type        = string
  default     = "arm-gcp-c4a-standard-48"
}

variable "timeout_secs" {
  description = "Maximum time to wait before destroying the VM via watchdog (seconds)"
  type        = number
  default     = 3600
}

variable "enable_watchdog" {
  description = "Enable automatic VM cleanup after timeout"
  type        = bool
  default     = false
}

################################################################################
# Event Stream Configuration
################################################################################
variable "event_stream_host" {
  description = "Event stream host for benchmark coordinator"
  type        = string
  default     = ""
}

variable "event_stream_port" {
  description = "Event stream port for benchmark coordinator"
  type        = string
  default     = "6379"
}

variable "event_stream_user" {
  description = "Event stream user for benchmark coordinator"
  type        = string
  default     = ""
}

variable "event_stream_pass" {
  description = "Event stream password for benchmark coordinator"
  type        = string
  default     = ""
  sensitive   = true
}

################################################################################
# Data Sink Configuration
################################################################################
variable "datasink_redistimeseries_host" {
  description = "RedisTimeSeries host for data sink"
  type        = string
  default     = ""
}

variable "datasink_redistimeseries_port" {
  description = "RedisTimeSeries port for data sink"
  type        = string
  default     = "6379"
}

variable "datasink_redistimeseries_pass" {
  description = "RedisTimeSeries password for data sink"
  type        = string
  default     = ""
  sensitive   = true
}

################################################################################
# Additional Configuration
################################################################################
variable "startup_script" {
  description = "Additional startup script to run"
  type        = string
  default     = ""
}

variable "deletion_protection" {
  description = "Enable deletion protection for the instance"
  type        = bool
  default     = false
}

################################################################################
# OS Configuration
################################################################################
variable "os" {
  description = "Operating system"
  type        = string
  default     = "ubuntu24.04"
}

variable "arch" {
  description = "Architecture"
  type        = string
  default     = "arm64"
}
