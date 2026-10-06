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
  validation {
    condition     = contains(["us-east-1a", "us-east-1b"], var.availability_zone)
    error_message = "availability_zone must be us-east-1a or us-east-1b (the shared public subnets)."
  }
}

# Memory bound: the ingester keeps every active series in memory (see README.md, "Sizing"). 4 vCPU, 32 GiB.
# Graviton (r7g.xlarge) works too, with an arm64 instance_ami: the bootstrap picks the binaries by architecture.
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

# grafana/mimir 3.2.1 (latest, 2026-09-10): the linux release binaries and their SHA-256 (the release's
# mimir-linux-<arch>-sha-256 assets). The bootstrap refuses a binary that doesn't match.
variable "mimir_version" {
  default = "3.2.1"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.mimir_version))
    error_message = "mimir_version must be X.Y.Z."
  }
}

variable "mimir_sha256" {
  type = map(string)
  default = {
    amd64 = "8df1ddd5de5a4ad75f3627050b063b19162ba3a20ad98a1e11aafcb0525c988f"
    arm64 = "925e7c8ada5c006866b598acb71f7cf41858d228a92848333d245a44fe293118"
  }
  validation {
    condition     = toset(keys(var.mimir_sha256)) == toset(["amd64", "arm64"]) && alltrue([for h in values(var.mimir_sha256) : can(regex("^[0-9a-f]{64}$", h))])
    error_message = "mimir_sha256 must map amd64 and arm64 to lowercase hex SHA-256s."
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
    condition     = alltrue([for c in var.read_allowed_cidrs : can(cidrhost(c, 0)) && try(tonumber(split("/", c)[1]) >= 16, false)])
    error_message = "read_allowed_cidrs must be CIDRs no wider than /16 (specific NAT egress addresses)."
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
# Defaults for every tenant; `tenants` overrides them per tenant. Changing a default replaces the instance
# (it's in the user-data); changing `tenants` doesn't. Sizing: README.md, "Sizing" and "Tenants".

variable "retention_period" {
  description = "compactor_blocks_retention_period: blocks older than this are deleted. 0 keeps them forever."
  default     = "0"
  validation {
    condition     = can(regex("^(0|([0-9]+(y|w|d|h|m|s|ms))+)$", var.retention_period))
    error_message = "retention_period must be 0 or a duration such as 400d."
  }
}

variable "max_series_per_tenant" {
  description = "max_global_series_per_user: active (in-memory) series per tenant, unless `tenants` says otherwise"
  type        = number
  default     = 300000
  validation {
    condition     = var.max_series_per_tenant > 0 && floor(var.max_series_per_tenant) == var.max_series_per_tenant
    error_message = "max_series_per_tenant must be a positive integer."
  }
}

variable "ingestion_rate" {
  description = "Samples per second per tenant, unless `tenants` says otherwise"
  type        = number
  default     = 20000
  validation {
    condition     = var.ingestion_rate > 0
    error_message = "ingestion_rate must be positive."
  }
}

variable "ingestion_burst_size" {
  description = "Samples per tenant above the rate a burst may take (a push larger than this is refused whole)"
  type        = number
  default     = 200000
  validation {
    condition     = var.ingestion_burst_size > 0 && floor(var.ingestion_burst_size) == var.ingestion_burst_size
    error_message = "ingestion_burst_size must be a positive integer."
  }
}

variable "max_label_names_per_series" {
  type    = number
  default = 64
  validation {
    condition     = var.max_label_names_per_series > 0 && floor(var.max_label_names_per_series) == var.max_label_names_per_series
    error_message = "max_label_names_per_series must be a positive integer."
  }
}

variable "max_label_name_length" {
  type    = number
  default = 1024
  validation {
    condition     = var.max_label_name_length > 0 && floor(var.max_label_name_length) == var.max_label_name_length
    error_message = "max_label_name_length must be a positive integer."
  }
}

variable "max_label_value_length" {
  description = "Also limits the metric name"
  type        = number
  default     = 4096
  validation {
    condition     = var.max_label_value_length > 0 && floor(var.max_label_value_length) == var.max_label_value_length
    error_message = "max_label_value_length must be a positive integer."
  }
}

variable "out_of_order_time_window" {
  description = "How far behind the tenant's newest sample a sample is still accepted (clients replay buffered samples after network blips)"
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
  default     = 2000000
  validation {
    condition     = var.max_series_total > 0 && floor(var.max_series_total) == var.max_series_total
    error_message = "max_series_total must be a positive integer."
  }
}

variable "max_ingestion_rate_total" {
  description = "ingester instance_limits.max_ingestion_rate: samples per second across all tenants"
  type        = number
  default     = 120000
  validation {
    condition     = var.max_ingestion_rate_total > 0
    error_message = "max_ingestion_rate_total must be positive."
  }
}

# The tenants that exist: nginx admits only users of these tenants (<tenant>-<role>-<1|2>), so a new tenant
# is a reviewed change here. The value overrides the default limits for that tenant ({} for the defaults);
# field names are Mimir's limits (YAML) names. Applied in place, within about 5 minutes. Never reuse a removed
# tenant's name: its data is kept, and the new owner would see it.
variable "tenants" {
  description = "Tenant name => Mimir limit overrides for it ({} for the defaults)"
  type        = any
  default = {
    # Redis Ultra perf benchmarks: a few concurrent runs, each a few thousand to tens of thousands of series.
    ultra = {
      max_global_series_per_user = 1500000
      ingestion_rate             = 100000
      ingestion_burst_size       = 1000000
    }
  }
  validation {
    condition = (
      can(keys(var.tenants)) && length(keys(var.tenants)) > 0 &&
      alltrue([for t in keys(var.tenants) : can(regex("^[a-z][a-z0-9_]{0,31}$", t))]) &&
      alltrue([for v in values(var.tenants) : v == null || can(keys(v))])
    )
    error_message = "tenants must be a non-empty map from tenant names ([a-z][a-z0-9_]{0,31}) to maps of Mimir limits ({} for the defaults)."
  }
}

variable "alarm_email" {
  description = "Email subscribed to the alarm topic; empty for none"
  default     = ""
}

variable "log_retention_days" {
  default = 30
}
