variable "region" {
  default = "us-east-1"
}

variable "setup_name" {
  description = "Name of the runner host and prefix of its resources (IAM role, SSM path): fixed once applied"
  default     = "e2e-bench-runner-us-east-1"
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

variable "availability_zone" {
  default = "us-east-1a"
}

# Same size as terraform/github-runner-cloud-benchmarks (m7i.8xlarge, 32 vCPU / 128 GiB): room for
# runner_count concurrent jobs, each mostly a go test that orchestrates remote infrastructure.
variable "instance_type" {
  default = "m7i.8xlarge"
}

# Ubuntu 26.04 LTS amd64 (Canonical ubuntu-resolute-26.04-amd64-server-20260916). Changing it applies only
# to a deliberate replacement (README): the instance ignores AMI and user-data changes.
variable "instance_ami" {
  default = "ami-09b09d2491cd88154"
}

variable "root_volume_size_gb" {
  description = "Same as terraform/github-runner-cloud-benchmarks; holds every runner's work dir and Go caches"
  default     = 1024
}

variable "runner_count" {
  description = "Runner processes on the host, each running one job at a time"
  type        = number
  default     = 20
  validation {
    condition     = var.runner_count >= 1 && var.runner_count <= 99
    error_message = "runner_count must be between 1 and 99."
  }
}

# actions/runner release, pinned by version and the sha256 its release notes publish for linux-x64.
variable "runner_version" {
  default = "2.337.0"
}

variable "runner_sha256" {
  default = "70920811a4f8ad4328818682bca5c6469c1c942fab52448868071d0063816613"
}

variable "alarm_email" {
  description = "Email subscribed to the alarm topic; empty for none (the repo is public: pass it with -var)"
  default     = ""
}
