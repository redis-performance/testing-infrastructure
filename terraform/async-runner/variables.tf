################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "async-runner"
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

variable "private_key_path" {
  description = "private key"
  default     = "/Users/anton.tokarev/.ssh/atokarev-softeq"
}

variable "key_name" {
  description = "key name"
  default     = "atokarev"
}

variable "region" {
  default = "us-east-2"
}

# (Ubuntu 20.04)
# ubuntu-bionic-20.04-amd64-server
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-2 Ubuntu 20.04 - perf-cto-base-image-ubuntu20.04-pd-0.7.40"
  default     = "ami-0cb81cb394fc2e305"
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
  default     = "100"
}

variable "redis_module" {
  description = "redis_module"
  default     = "N/A"
}

variable "instance_volume_size" {
  description = "EC2 instance volume_size"
  default     = "100"
}


variable "client_instance_volume_size" {
  description = "EC2 instance volume_size"
  default     = "100"
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

variable "runner_instance_type" {
  description = "type for aws EC2 instance"
  default     = "t2.xlarge"
}


variable "runner_instance_count" {
  default = "1"
}

variable "runner_instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 4
}
