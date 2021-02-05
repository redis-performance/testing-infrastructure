################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "oss-redisgraph-standalone-r5"
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

variable "github_org" {
  description = "	The owner name. For example, RedisModules."
  default     = "N/A"
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
  default     = "/tmp/benchmarks.redislabs.redisgraph.pem"
}

variable "public_key" {
  description = "public key"
  default     = "~/.ssh/perf-cto-joint-tasks.pub"
}

variable "key_name" {
  description = "key name"
  default     = "perf-cto-joint-tasks"
}

variable "region" {
  default = "us-east-2"
}

# (Ubuntu 18.04)
# ubuntu-bionic-18.04-amd64-server-20201026
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-2 Ubuntu 18.04 - perf-cto-base-image-redis6.0.10"
  default     = "ami-0f94595d359cdfe44"
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

################################################################################
# Specific DB machine variables
################################################################################
# r5.8xlarge 	32 VCPUs 	256 GB MEM
variable "server_instance_type" {
  description = "type for aws EC2 instance"
  default     = "r5.8xlarge"
}

variable "server_instance_count" {
  default = "1"
}

variable "server_instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 16
}


################################################################################
# Specific Client machine variables
################################################################################
# r5.8xlarge 	8 VCPUs 	16 GB MEM

variable "client_instance_type" {
  description = "type for aws EC2 instance"
  default     = "c5.2xlarge"
}

variable "client_instance_count" {
  default = "1"
}

variable "client_instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 16
}

