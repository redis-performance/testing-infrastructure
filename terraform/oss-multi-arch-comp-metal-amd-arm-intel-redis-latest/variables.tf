################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "oss-multi-arch-comp-metal-amd-arm-intel-redis-latest"
}

variable "github_actor" {
  description = "The name of the person or app that initiated the deployment."
  default     = "N/A"
}

variable "github_org" {
  description = "The owner name. For example, RedisModules."
  default     = "N/A"
}

variable "github_repo" {
  description = "The owner and repository name. For example, octocat/Hello-World."
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

variable "triggering_env" {
  description = "The triggering environment. For example circleci."
  default     = "N/A"
}

variable "environment" {
  description = "The cost tag."
  default     = "N/A"
}

variable "redis_module" {
  description = "redis_module"
  default     = "N/A"
}

################################################################################
# Instance(s) options
################################################################################

variable "region" {
  default = "us-east-2"
}

variable "server_instances_configs" {
  description = "Configuration for each instance type"
  type = map(object({
    name          = string
    instance_type = string
    ami           = string
    arch_label    = string
  }))
  default = {
    "amd" = {
      name          = "AMD m7a.metal-48xl"
      instance_type = "m7a.metal-48xl"
      ami           = "ami-04f167a56786e4b09" # Ubuntu 24.04 LTS x86_64
      arch_label    = "AMD"
    },
    "intel" = {
      name          = "Intel m7i.metal-24xl"
      instance_type = "m7i.metal-24xl"
      ami           = "ami-04f167a56786e4b09" # Ubuntu 24.04 LTS x86_64
      arch_label    = "INTEL"
    },
    "arm" = {
      name          = "ARM m8g.metal-24xl"
      instance_type = "m8g.metal-24xl"
      ami           = "ami-0ae6f07ad3a8ef182" # Ubuntu 24.04 LTS ARM64
      arch_label    = "ARM"
    }
  }
}

variable "client_instance_ami" {
  description = "AMI for aws EC2 instance - Ubuntu 24.04 LTS x86_64"
  default     = "ami-04f167a56786e4b09"
}

variable "client_instance_type" {
  description = "type for aws EC2 instance"
  default     = "c6in.8xlarge"
}

variable "instance_volume_size" {
  description = "EC2 instance volume_size"
  default     = "128"
}

variable "instance_volume_type" {
  description = "EC2 instance volume_type"
  default     = "gp3"
}


variable "instance_volume_encrypted" {
  description = "EC2 instance instance_volume_encrypted"
  default     = "false"
}

################################################################################
# SSH Access
################################################################################
variable "private_key" {
  description = "private key"
  default     = "/tmp/benchmarks.redislabs.pem"
}

variable "key_name" {
  description = "key name"
  default     = "perf-cto-us-east-2"
}

variable "ssh_user" {
  description = "ssh_user"
  default     = "ubuntu"
}

# Define base tags that are common to multiple resources
locals {
  base_tags = {
    Environment    = var.environment
    setup          = var.setup_name
    redis_module   = var.redis_module
    triggering_env = var.triggering_env
    github_actor   = var.github_actor
    github_org     = var.github_org
    github_repo    = var.github_repo
    github_sha     = var.github_sha
    timeout_secs   = var.timeout_secs
  }
}
