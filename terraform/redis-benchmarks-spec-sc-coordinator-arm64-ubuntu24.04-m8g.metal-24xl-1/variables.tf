################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "redis-benchmarks-spec-sc-coordinator-arm64-ubuntu24.04-m8g.metal-24xl-1"
}
variable "github_actor" {
  description = "The name of the person or app that initiated the deployment."
  default     = "N/A"
}

variable "github_repo" {
  description = "	The owner and repository name. For example, octocat/Hello-World."
  default     = "redis/redis"
}

variable "github_sha" {
  description = "The commit SHA that triggered the deployment."
  default     = "N/A"
}

variable "timeout_secs" {
  description = "The maximum time to wait prior destroying the VM via the watchdog."
  default     = "3600"
}

variable "environment" {
  description = "Cost Environment name."
  default     = "OSS-SPEC-ARM"
}


################################################################################
# Access keys
################################################################################
variable "private_key" {
  description = "private key"
  default     = "~/.ssh/benchmarksredislabsus-east-1.pem"
}

variable "key_name" {
  description = "key name"
  default     = "benchmarks.redislabs.us-east-1"
}

variable "region" {
  default = "us-east-1"
}

# (Ubuntu 18.04)
# ubuntu-bionic-18.04-amd64-server-20201026
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-1 Ubuntu 24.04 arm64"
  default     = "ami-0aa307ed50ca3e58f"
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
  default     = "256"
}

variable "instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp3"
}

variable "instance_volume_iops" {
  description = "EC2 instance volume_iops"
  default     = "384"
}

variable "instance_volume_encrypted" {
  description = "EC2 instance instance_volume_encrypted"
  default     = "false"
}

variable "instance_root_block_device_encrypted" {
  description = "EC2 instance instance_root_block_device_encrypted"
  default     = "false"
}

# Model	c5.large
variable "instance_type" {
  description = "type for aws EC2 instance"
  default     = "m8g.metal-24xl"
}

variable "server_instance_count" {
  default = "1"
}

variable "instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 96
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
# Benchmark runner configuration
################################################################################
variable "platform_name" {
  description = "Platform name for the benchmark coordinator"
  default     = "arm-aws-m8g.metal-24xl"
}

variable "event_stream_host" {
  description = "Event stream host for benchmark coordinator"
  default     = ""
}

variable "event_stream_port" {
  description = "Event stream port for benchmark coordinator"
  default     = ""
}

variable "event_stream_user" {
  description = "Event stream user for benchmark coordinator"
  default     = ""
}

variable "event_stream_pass" {
  description = "Event stream password for benchmark coordinator"
  type        = string
  sensitive   = true
  default     = ""
}

variable "datasink_redistimeseries_host" {
  description = "RedisTimeSeries host for data sink"
  default     = ""
}

variable "datasink_redistimeseries_port" {
  description = "RedisTimeSeries port for data sink"
  default     = ""
}

variable "datasink_redistimeseries_pass" {
  description = "RedisTimeSeries password for data sink"
  type        = string
  sensitive   = true
  default     = ""
}

# Architecture for the benchmark runner (e.g., arm64, amd64)
variable "arch" {
  description = "Architecture for the benchmark runner"
  default     = "arm64"
}
