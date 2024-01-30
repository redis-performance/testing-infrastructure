################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "perf-cto-RE-7nodes-us-east-1-i4i.8xlarge-cluster-1"
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
  default     = "N/A"
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

# (Ubuntu 18.04)
# ubuntu-bionic-18.04-amd64-server-20230531
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-1 Ubuntu 18.04"
  default     = "ami-055744c75048d8296"
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
  default     = "1024"
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
  default     = "ubuntu18.04"
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
  default     = "i4i.8xlarge"
}


variable "server_instance_count" {
  default = "7"
}

variable "server_instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 16
}


