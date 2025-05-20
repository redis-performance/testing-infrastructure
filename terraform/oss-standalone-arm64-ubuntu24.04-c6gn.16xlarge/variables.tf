################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "oss-standalone-arm64-ubuntu24.04-c6gn.16xlarge"
}

variable "github_actor" {
  description = "The name of the person or app that initiated the deployment."
  default     = "N/A"
}

variable "github_repo" {
  description = "	The owner and repository name. For example, octocat/Hello-World."
  default     = "N/A"
}

variable "github_sha" {
  description = "The commit SHA that triggered the deployment."
  default     = "N/A"
}

variable "environment" {
  description = "	The cost tag."
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
  default     = "/tmp/benchmarks.redislabs.pem"
}

variable "public_key" {
  description = "public key"
  default     = "~/.ssh/perf-ci.pub"
}

variable "key_name" {
  description = "key name"
  default     = "perf-ci"
}

variable "region" {
  default = "us-east-2"
}

# (Ubuntu 24.04 LTS) ARM
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-2 Ubuntu 24.04"
  default     = "ami-0ae6f07ad3a8ef182"
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
  default     = "128"
}

variable "instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp3"
}

variable "instance_volume_iops" {
  description = "EC2 instance volume_iops"
  default     = "100"
}

variable "instance_volume_encrypted" {
  description = "EC2 instance instance_volume_encrypted"
  default     = "false"
}

variable "instance_root_block_device_encrypted" {
  description = "EC2 instance instance_root_block_device_encrypted"
  default     = "false"
}

# Model	c6gn.16xlarge
variable "instance_type" {
  description = "type for aws EC2 instance"
  default     = "c6gn.16xlarge"
}

variable "server_instance_count" {
  default = "1"
}


variable "client_instance_count" {
  default = "2"
}

variable "instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 32
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
