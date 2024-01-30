################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "gp3-c5-2xlarge-42gb"
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
# ubuntu-bionic-18.04-amd64-server-20230329
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-1 Ubuntu 18.04"
  default     = "ami-047aac48e2ffc201f"
}

variable "instance_device_name" {
  description = "EC2 instance device name"
  default     = "/dev/sdp"
}

variable "redis_module" {
  description = "redis_module"
  default     = "N/A"
}

variable "instance_volume_size" {
  description = "EC2 instance volume_size"
  default     = "42"
}

variable "instance_volume_iops" {
  description = "EC2 instance instance_volume_iops"
  default     = "3000"
}

variable "instance_volume_throughput" {
  description = "EC2 instance instance_volume_throughput"
  default     = "125"
}

variable "instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp3"
}


variable "instance_volume_encrypted" {
  description = "EC2 instance instance_volume_encrypted"
  default     = "true"
}

variable "instance_root_block_device_encrypted" {
  description = "EC2 instance instance_root_block_device_encrypted"
  default     = "false"
}

# Model	c5.large
variable "instance_type" {
  description = "type for aws EC2 instance"
  default     = "c5.2xlarge"
}

variable "server_instance_count" {
  default = "1"
}

variable "os" {
  description = "os"
  default     = "ubuntu18.04"
}

variable "ssh_user" {
  description = "ssh_user"
  default     = "ubuntu"
}
