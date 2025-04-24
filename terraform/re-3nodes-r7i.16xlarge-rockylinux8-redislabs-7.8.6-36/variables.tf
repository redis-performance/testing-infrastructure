################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "perf-cto-RE-3nodes-r7i.16xlarge-rockylinux8-RS-7.8.6-36"
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
  default     = "RED-158033"
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
  default     = "/tmp/benchmarks.redislabs.pem"
}

variable "key_name" {
  description = "key name"
  default     = "perf-cto-us-east-2"
}

variable "region" {
  default = "us-east-2"
}

# Rocky Linux 8 (Official)Rocky Linux 8 (Official)
# https://aws.amazon.com/marketplace/server/configuration?productId=d6577ceb-8ea8-4e0e-84c6-f098fc302e82&ref_=psb_cfg_continue
# Ami Id: ami-02391db2758465a87
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-2 Rocky Linux 8"
  default     = "ami-02391db2758465a87"
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
  default     = "rockylinux8"
}

variable "ssh_user" {
  description = "ssh_user"
  default     = "rocky"
}

################################################################################
# Specific DB machine variables
################################################################################
# r7i.16xlarge 	64 VCPUs 512 GB
variable "server_instance_type" {
  description = "type for aws EC2 instance"
  default     = "r7i.16xlarge"
}


variable "server_instance_count" {
  default = "3"
}

variable "server_instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 32
}
