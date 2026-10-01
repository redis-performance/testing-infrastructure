variable "region" {
  default = "us-east-1"
}

variable "setup_name" {
  description = "Name of the server and prefix of its resources (bucket, IAM roles, SSM paths, log groups): fixed once applied"
  default     = "ultra-pyroscope-us-east-1"
}

variable "environment" {
  description = "Cost tag"
  default     = "performance-cto"
}

variable "github_actor" {
  description = "The name of the person or app that initiated the deployment (owner tag). Applied by hand, so it defaults to the owner's account-wide tag value."
  default     = "filipe_oliveira"
}

variable "github_repo" {
  default = "redis-performance/testing-infrastructure"
}

variable "github_sha" {
  default = "N/A"
}

# The metastore EBS volume can't move between AZs, so the instance and the volume are pinned to one.
variable "availability_zone" {
  default = "us-east-1a"
}

variable "instance_type" {
  default = "m7i.xlarge"
}

# Ubuntu 26.04 LTS amd64 (Canonical ubuntu-resolute-26.04-amd64-server-20260916). Pinned: an AMI change
# replaces the instance (the metastore volume and the certificates survive it).
variable "instance_ami" {
  default = "ami-09b09d2491cd88154"
}

variable "root_volume_size_gb" {
  default = 40
}

variable "metastore_volume_size_gb" {
  default = 20
}

# grafana/pyroscope:2.3.1 (latest, 2026-09-08), pinned by index digest.
variable "pyroscope_image" {
  default = "grafana/pyroscope:2.3.1@sha256:86a9ee7448487409ead8ada78789de7b78b739711b92b5d7224a1a54abf3eeb2"
}

variable "hostname" {
  description = "Public name; an A record for the EIP in the cto.redislabs.com zone (CTO account), created outside this module"
  default     = "pyroscope.cto.redislabs.com"
}

variable "acme_email" {
  description = "Let's Encrypt account email for expiry notices; empty registers without one (the watchdog alarms 14 days before expiry)"
  default     = ""
}

variable "read_allowed_cidrs" {
  description = "Sources allowed on the query paths: the neptune-dev Grafana's NAT egress"
  type        = list(string)
  default     = ["35.174.252.24/32"]
  validation {
    condition     = alltrue([for c in var.read_allowed_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "read_allowed_cidrs must be CIDRs, and not 0.0.0.0/0."
  }
}

# nginx.org stable (1.30.x), from its signed apt repository; Ubuntu's own nginx lags (1.28 on 26.04).
variable "nginx_channel" {
  description = "nginx.org package channel: \"stable\" or \"mainline\""
  default     = "stable"
  validation {
    condition     = contains(["stable", "mainline"], var.nginx_channel)
    error_message = "nginx_channel must be stable or mainline."
  }
}

# 0 keeps profiles forever.
variable "retention_period" {
  default = "0"
}

variable "alarm_email" {
  description = "Email subscribed to the alarm topic; empty for none"
  default     = ""
}

variable "log_retention_days" {
  default = 30
}
