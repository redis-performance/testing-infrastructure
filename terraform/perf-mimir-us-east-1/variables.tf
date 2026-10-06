variable "region" {
  default = "us-east-1"
}

variable "setup_name" {
  description = "Name of the server and prefix of its resources (bucket, IAM roles, SSM paths, log groups): fixed once applied"
  default     = "perf-mimir-us-east-1"
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

# The data EBS volume can't move between AZs, so the instance and the volume are pinned to one.
variable "availability_zone" {
  default = "us-east-1a"
}

# Memory bound: the ingester keeps every active series in memory (see README.md, "Sizing"). 4 vCPU, 32 GiB.
# x86_64 only: the AMI and the Mimir download are amd64.
variable "instance_type" {
  default = "r7i.xlarge"
}

# Ubuntu 26.04 LTS amd64 (Canonical ubuntu-resolute-26.04-amd64-server-20260916). Pinned: an AMI change
# replaces the instance (the data volume and the certificates survive it).
variable "instance_ami" {
  default = "ami-09b09d2491cd88154"
}

variable "root_volume_size_gb" {
  default = 40
}

# The ingester's WAL and TSDB head (and its last 13 h of blocks), compaction scratch space, the store-gateway's
# index headers and the TLS certificates.
variable "data_volume_size_gb" {
  default = 150
}

# grafana/mimir 3.2.1 (latest, 2026-09-10): the linux-amd64 release binary and its SHA-256 (the release's
# mimir-linux-amd64-sha-256 asset). The bootstrap refuses a binary that doesn't match.
variable "mimir_version" {
  default = "3.2.1"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.mimir_version))
    error_message = "mimir_version must be X.Y.Z."
  }
}

variable "mimir_sha256" {
  default = "8df1ddd5de5a4ad75f3627050b063b19162ba3a20ad98a1e11aafcb0525c988f"
  validation {
    condition     = can(regex("^[0-9a-f]{64}$", var.mimir_sha256))
    error_message = "mimir_sha256 must be a lowercase hex SHA-256."
  }
}

variable "hostname" {
  description = "Public name; an A record for the EIP in the cto.redislabs.com zone (CTO account), created outside this module"
  default     = "metrics.cto.redislabs.com"
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

# --- Mimir limits ------------------------------------------------------------------------------------
# Defaults for every tenant; tenant_limits overrides them per tenant. Changing a default replaces the
# instance (it's in the user-data); changing tenant_limits doesn't.

variable "retention_period" {
  description = "compactor_blocks_retention_period: blocks older than this are deleted. 0 keeps them forever."
  default     = "0"
  validation {
    condition     = can(regex("^(0|([0-9]+(y|w|d|h|m|s|ms))+)$", var.retention_period))
    error_message = "retention_period must be 0 or a duration such as 400d."
  }
}

variable "max_series_per_tenant" {
  description = "max_global_series_per_user: active (in-memory) series per tenant"
  type        = number
  default     = 2000000
}

variable "ingestion_rate" {
  description = "Samples per second per tenant"
  type        = number
  default     = 100000
}

variable "ingestion_burst_size" {
  description = "Samples per tenant above the rate a burst may take (a push larger than this is refused whole)"
  type        = number
  default     = 1000000
}

variable "max_label_names_per_series" {
  type    = number
  default = 64
}

variable "max_label_name_length" {
  type    = number
  default = 1024
}

variable "max_label_value_length" {
  description = "Also limits the metric name"
  type        = number
  default     = 4096
}

variable "out_of_order_time_window" {
  description = "How far behind a series' newest sample a sample is still accepted (clients replay buffered samples after network blips)"
  default     = "1h"
  validation {
    condition     = can(regex("^(0|([0-9]+(h|m|s))+)$", var.out_of_order_time_window))
    error_message = "out_of_order_time_window must be 0 or a duration such as 1h."
  }
}

# Whole-server guards, across tenants: what the instance can hold, whatever the per-tenant limits add up to.
# Above them the ingester refuses pushes (clients retry) instead of running out of memory.
variable "max_series_total" {
  description = "ingester instance_limits.max_series: active series across all tenants (size it to the instance's memory)"
  type        = number
  default     = 2500000
}

variable "max_ingestion_rate_total" {
  description = "ingester instance_limits.max_ingestion_rate: samples per second across all tenants"
  type        = number
  default     = 150000
}

variable "tenant_limits" {
  description = "Per-tenant overrides of Mimir limits, e.g. { ultra = { max_global_series_per_user = 3000000 } }. Field names are Mimir's limits (YAML) names. Applied in place, within about 5 minutes."
  type        = any
  default     = {}
  validation {
    condition     = can(keys(var.tenant_limits)) && alltrue([for t in keys(var.tenant_limits) : can(regex("^[a-z][a-z0-9_]{0,31}$", t))])
    error_message = "tenant_limits must be a map keyed by tenant names ([a-z][a-z0-9_]{0,31})."
  }
}

variable "alarm_email" {
  description = "Email subscribed to the alarm topic; empty for none"
  default     = ""
}

variable "log_retention_days" {
  default = 30
}
