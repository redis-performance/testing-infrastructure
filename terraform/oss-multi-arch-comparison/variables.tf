################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "oss-multi-arch"
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



variable "redis_module" {
  description = "redis_module"
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
  default     = "perf-ci"
}

variable "region" {
  default = "us-east-2"
}

# (Ubuntu 18.04)
# us-east-2	bionic	18.04 LTS	amd64	hvm:ebs-ssd	20221201	ami-04fa64c4b38e36384	hvm
# us-east-2	bionic	18.04 LTS	arm64	hvm:ebs-ssd	20221207	ami-0cae502708343c09b	hvm
# us-east-2	jammy	22.04	amd64	hvm:ebs-ssd	20221206	ami-0ff39345bd62c82a5 hvm

variable "client_instance_ami" {
  description = "AMI for aws EC2 instance - us-east-2 Ubuntu 18.04 - amd64"
  default     = "ami-0ff39345bd62c82a5"
}

variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-2 Ubuntu 18.04 - amd64"
  default     = "ami-04fa64c4b38e36384"
}

variable "instance_ami_arm64" {
  description = "AMI for aws EC2 instance - us-east-2 Ubuntu 18.04 - arm64"
  default     = "ami-0cae502708343c09b"
}


variable "instance_device_name" {
  description = "EC2 instance device name"
  default     = "/dev/sda1"
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
# Specific Client machine variables
################################################################################
# c5n.4xlarge 	16 VCPUs

variable "client_instance_type" {
  description = "type for aws EC2 instance"
  default     = "c5n.4xlarge"
}


variable "db_instance_count" {
  default = "1"
}


variable "client_instance_count" {
  default = "16"
}

variable "client_instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 8
}
