################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "oss-redisearch-m7i-metal"
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
  default     = "RediSearch"
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

# redisbench-admin sums a 600s-per-spec default, so a narrow run gets a budget
# the watchdog enforces long before a bare-metal host has booted and finished
# its spec. Floor the tag the watchdog reads at 4h.
locals {
  effective_timeout_secs = max(tonumber(var.timeout_secs), 14400)
}



################################################################################
# Access keys
################################################################################
variable "private_key" {
  description = "private key"
  default     = "/tmp/benchmarks.redislabs.pem"
}

variable "key_name" {
  description = "key name"
  default     = "perf-cto-us-east-2"
}

variable "region" {
  default = "us-east-2"
}

# Ubuntu 24.04, redis 8.10.1 sha=3399357e, memtier sha=ecadcd68.
# Redis >= 8.10 is required for RedisModule_AddPostNotificationJobForKey (used by RediSearch master).
# Same image as oss-standalone-redisearch-m7.
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-2 Ubuntu 24.04 - perf-base-image-ubuntu24.04-m6i.8xlarge-20260827-0153"
  default     = "ami-0970faf3f922aa7f4"
}

variable "instance_device_name" {
  description = "EC2 instance device name"
  default     = "/dev/sda1"
}


variable "instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp3"
}

variable "instance_volume_iops" {
  description = "EC2 instance volume_iops"
  default     = "100"
}

variable "redis_module" {
  description = "redis_module"
  default     = "N/A"
}

variable "instance_volume_size" {
  description = "EC2 instance volume_size"
  default     = "128"
}


variable "client_instance_volume_size" {
  description = "EC2 instance volume_size"
  default     = "64"
}

variable "client_instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp3"
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
  default     = "ubuntu24.04"
}

variable "ssh_user" {
  description = "ssh_user"
  default     = "ubuntu"
}

################################################################################
# Specific DB machine variables
################################################################################
# m7i.metal-24xl	96 VCPUs	384 GB MEM	Intel Xeon 8488C (Sapphire Rapids), 2 sockets, bare metal
variable "server_instance_type" {
  description = "type for aws EC2 instance"
  default     = "m7i.metal-24xl"
}


variable "server_instance_count" {
  default = "1"
}

variable "server_instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 16
}

variable "server_instance_cpu_threads_per_core" {
  description = "CPU threads per CORE"
  default     = 1
}

################################################################################
# Specific Client machine variables
################################################################################
# m7i.4xlarge 	16 VCPUs

variable "client_instance_type" {
  description = "type for aws EC2 instance"
  default     = "m7i.4xlarge"
}

variable "client_instance_count" {
  default = "1"
}

################################################################################
# Polar Signals / Parca agent configuration
################################################################################
variable "enable_parca_agent" {
  description = "Enable Polar Signals Parca agent installation on DB server"
  type        = bool
  default     = false
}

variable "parca_agent_token" {
  description = "Bearer token for Polar Signals remote store (required if enable_parca_agent is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "parca_agent_project_id" {
  description = <<-EOT
    Polar Signals project id. Required when parca_agent_token is a
    `psc_v1_<secret>_<serviceAccountId>` (no project binding in the
    token) -- passed to parca-agent as `--remote-store-grpc-headers=projectID=<id>`
    so the server can route writes to the right project. Leave empty
    when parca_agent_token is a JWT (`eyJ...`) with `projectId` already
    embedded in its claims.
  EOT
  type        = string
  default     = ""
}

variable "parca_agent_snap_channel" {
  description = <<-EOT
    Snap channel for parca-agent. v0.46.0 (stable) does not honor the
    projectID gRPC header with `psc_v1_` tokens; use `edge` (v0.47.1+)
    for that workflow. Safe to leave as `stable` when using a JWT token
    with the project id embedded.
  EOT
  type        = string
  default     = "stable"
}
