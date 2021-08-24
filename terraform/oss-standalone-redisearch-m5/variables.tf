################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "oss-redisearch-m5"
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
  default     = "/tmp/benchmarks.redislabs.pem"
}

variable "key_name" {
  description = "key name"
  default     = "perf-cto-joint-tasks"
}

variable "region" {
  default = "us-east-2"
}

variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-2 Ubuntu 18.04 - perf-cto-base-image-redis6.2.4"
  default     = "ami-0dfc19c2cc59ed638"
}

variable "instance_device_name" {
  description = "EC2 instance device name"
  default     = "/dev/sda1"
}


variable "instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp2"
}

variable "instance_volume_iops" {
  description = "EC2 instance volume_iops"
  default     = "384"
}

variable "redis_module" {
  description = "redis_module"
  default     = "N/A"
}

variable "instance_volume_size" {
  description = "EC2 instance volume_size"
  default     = "1024"
}


variable "client_instance_volume_size" {
  description = "EC2 instance volume_size"
  default     = "256"
}

variable "client_instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp2"
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
  default     = "ubuntu20.04"
}

variable "ssh_user" {
  description = "ssh_user"
  default     = "ubuntu"
}

################################################################################
# Specific DB machine variables
################################################################################
# m5d.8xlarge 	32 VCPUs 	128 GB MEM
variable "server_instance_type" {
  description = "type for aws EC2 instance"
  default     = "m5.8xlarge"
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
# m5.8xlarge 	32 VCPUs 	128 GB MEM

variable "client_instance_type" {
  description = "type for aws EC2 instance"
  default     = "m5.8xlarge"
}

variable "client_instance_count" {
  default = "1"
}
