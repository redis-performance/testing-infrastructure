variable "region" {
  default = "us-east-1"
}

variable "owner" {
  description = "owner tag, applied by hand so it defaults to the account-wide value"
  default     = "filipe_oliveira"
}

variable "instance_type" {
  default = "m7i.2xlarge"
}

# Adopted, not rebuilt: the instance ignores AMI changes (see main.tf).
variable "instance_ami" {
  default = "ami-0bcc094591f354be2"
}

variable "key_name" {
  default = "benchmarks.redislabs.us-east-1"
}

variable "subnet_id" {
  description = "Default-VPC subnet in us-east-1a"
  default     = "subnet-e85eb4c2"
}

variable "security_group_id" {
  description = "benchmarks.redislabs.sg, shared with the coordinators and builders"
  default     = "sg-046d72511dd949d2b"
}

variable "proxy_eip" {
  description = "EIP of benchmarks.redislabs.com-PROXY-1 (us-east-2), whose HAProxy forwards the webhook to this host"
  default     = "18.116.150.197"
}

variable "mirror_port" {
  description = "Port on this host that receives the mirrored webhook requests"
  default     = 14999
}
