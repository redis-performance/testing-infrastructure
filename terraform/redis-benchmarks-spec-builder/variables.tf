################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "redis-benchmarks-spec-builder"
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
  description = "	The commit SHA that triggered the deployment."
  default     = "N/A"
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
  description = "AMI for aws EC2 instance - us-east-1 Ubuntu 18.04"
  default     = "ami-0bcc094591f354be2"
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
  default     = "1023"
}

variable "instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp2"
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
  default     = "c5.9xlarge"
}

variable "server_instance_count" {
  default = "1"
}

variable "instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 18
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
  default     = "ubuntu18.04"
}

variable "ssh_user" {
  description = "ssh_user"
  default     = "ubuntu"
}