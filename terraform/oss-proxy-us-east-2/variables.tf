variable "region" {
  default = "us-east-2"
}

variable "setup_name" {
  default = "benchmarks.redislabs.com-PROXY-2"
}

variable "owner" {
  default = "filipe_oliveira"
}

variable "instance_type" {
  description = "Same as PROXY-1"
  default     = "c7i.xlarge"
}

# Ubuntu 24.04 LTS amd64 (Canonical, /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3).
# Ignored after creation: changing it applies only to a deliberate replacement.
variable "instance_ami" {
  default = "ami-0fc53b217ec1ad816"
}

variable "key_name" {
  default = "perf-cto-us-east-2"
}

variable "subnet_id" {
  description = "Same subnet as PROXY-1 (us-east-2a): the private backends (10.3.x) are reachable from it"
  default     = "subnet-0597ccd9e8d2a050e"
}

variable "security_group_id" {
  description = "perf-cto-sg, the group PROXY-1 uses (already opens the proxy's listener ports)"
  default     = "sg-00512feb74e67d7cb"
}

variable "root_volume_size_gb" {
  default = 30
}

variable "proxy_eip_allocation_id" {
  description = "benchmarks-redislabs-eip"
  default     = "eipalloc-0b47bbade74616b3c"
}
