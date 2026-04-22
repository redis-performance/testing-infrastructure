################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "oss-redisearch-m7-aarch64"
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
  default     = "RediSearch"
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

# (Ubuntu 24.04 aarch64, memtier_benchmark v=255.255.255 sha=2f74d611:0 and
# redis Redis server v=8.6.2 sha=a176d122:0 -- aligned with the x86 side so
# a delta between this setup and oss-standalone-redisearch-m7 reflects arch,
# not binary versions. Built from the updated install scripts in
# perf-base-image-ubuntu24.04-aarch64-m7g.8xlarge/.)
# https://us-east-2.console.aws.amazon.com/ec2/home?region=us-east-2#ImageDetails:imageId=ami-07b2bd887269522a3
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-2 Ubuntu 24.04 aarch64 - perf-base-image-ubuntu24.04-aarch64-m7g.8xlarge-20260422-0313"
  default     = "ami-07b2bd887269522a3"
}

variable "instance_device_name" {
  description = "EC2 instance device name"
  default     = "/dev/sda1"
}


variable "instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp3"
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
  default     = "128"
}


variable "client_instance_volume_size" {
  description = "EC2 instance volume_size"
  default     = "64"
}

variable "client_instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp3"
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
  default     = "ubuntu24.04"
}

variable "ssh_user" {
  description = "ssh_user"
  default     = "ubuntu"
}

################################################################################
# Specific DB machine variables
################################################################################
# m7g.8xlarge 	32 VCPUs 	128 GB MEM 	AWS Graviton3 (Neoverse-V1)
# CPU options below cap to 16 physical cores / 1 thread per core to match
# the x86 m7i.8xlarge effective capacity (16 cores, SMT off).
variable "server_instance_type" {
  description = "type for aws EC2 instance"
  default     = "m7g.8xlarge"
}


variable "server_instance_count" {
  default = "1"
}

variable "server_instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 16
}

variable "server_instance_cpu_threads_per_core" {
  description = "CPU threads per CORE"
  default     = 1
}

################################################################################
# Specific Client machine variables
################################################################################
# m7g.4xlarge 	16 VCPUs — symmetric with x86 m7i.4xlarge client

variable "client_instance_type" {
  description = "type for aws EC2 instance"
  default     = "m7g.4xlarge"
}

variable "client_instance_count" {
  default = "1"
}

################################################################################
# Polar Signals / Parca agent configuration
################################################################################
variable "enable_parca_agent" {
  description = "Enable Polar Signals Parca agent installation on DB server"
  type        = bool
  default     = false
}

variable "parca_agent_token" {
  description = "Bearer token for Polar Signals remote store (required if enable_parca_agent is true)"
  type        = string
  default     = ""
  sensitive   = true
}
