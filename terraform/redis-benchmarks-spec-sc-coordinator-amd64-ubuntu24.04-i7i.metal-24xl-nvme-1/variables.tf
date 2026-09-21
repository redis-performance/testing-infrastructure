################################################################################
# Variables used for deployment tag
################################################################################

variable "setup_name" {
  description = "setup name"
  default     = "redis-benchmarks-spec-sc-coordinator-amd64-ubuntu24.04-i7i.metal-24xl-nvme-1"
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

variable "environment" {
  description = "Cost Environment name."
  default     = "OSS-SPEC-INTEL-METAL-NVME"
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

# Noble Numbat 24.04 LTS amd64 hvm:ebs-ssd-gp3 20260904
variable "instance_ami" {
  description = "AMI for aws EC2 instance - us-east-1 Ubuntu 24.04 amd64"
  default     = "ami-025d99823a4caad37"
}

variable "instance_device_name" {
  description = "EC2 instance device name"
  default     = "/dev/sda1"
}

variable "redis_module" {
  description = "redis_module"
  default     = "N/A"
}

################################################################################
# Root volume
#
# Holds the OS, docker images and build artifacts only. Benchmark data never
# lands here -- prepare_storage.sh fails rather than falling back to it.
################################################################################
variable "instance_volume_size" {
  description = "EC2 instance root volume_size"
  default     = "256"
}

variable "instance_volume_type" {
  description = "EC2 instance root volume_type"
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

################################################################################
# Dedicated EBS benchmark-data volume
#
# This is the EBS arm of the comparison. Unlike the root volume these values are
# set EXPLICITLY rather than left at provider defaults, because
# testing-infrastructure#162 requires the EBS tier under test to be a recorded,
# deliberate choice.
#
# The existing fleet runners sit at gp3 defaults (3000 IOPS / 125 MiB/s) because
# their root_block_device never sets throughput or iops. That 125 MiB/s ceiling
# is what the #577 full-sync cohort measured. Defaulting this volume to the same
# tier makes the first comparison an apples-to-apples reproduction of the
# existing cohort; raise it to test sensitivity to the storage ceiling.
################################################################################
variable "ebs_data_volume_size" {
  description = "Size (GiB) of the dedicated EBS benchmark-data volume"
  default     = 512
}

variable "ebs_data_volume_type" {
  description = "Volume type of the dedicated EBS benchmark-data volume"
  default     = "gp3"
}

variable "ebs_data_volume_iops" {
  description = "Provisioned IOPS of the dedicated EBS benchmark-data volume (gp3 baseline 3000)"
  default     = 3000
}

variable "ebs_data_volume_throughput" {
  description = "Provisioned throughput in MiB/s of the dedicated EBS benchmark-data volume (gp3 baseline 125, max 1000)"
  default     = 125
}

variable "ebs_data_device_name" {
  description = "Block device name for the dedicated EBS benchmark-data volume"
  default     = "/dev/sdf"
}

################################################################################
# Instance
################################################################################
variable "instance_type" {
  description = "type for aws EC2 instance"
  default     = "i7i.metal-24xl"
}

variable "server_instance_count" {
  default = "1"
}

variable "instance_cpu_core_count" {
  description = "CPU core count for aws EC2 instance"
  default     = 48
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
# Benchmark runner configuration
################################################################################

# The coordinator publishes results namespaced by platform name. Each storage
# condition gets its own suffixed name (-nvme / -ebs) so the two baselines stay
# distinct in the timeseries DB, as #162 requires. benchmark-storage-condition
# applies the suffix; this is the stem.
variable "platform_name_base" {
  description = "Platform name stem; -nvme / -ebs is appended per storage condition"
  default     = "x86-aws-i7i.metal-24xl"
}

variable "default_storage_condition" {
  description = "Storage condition to configure at first boot (nvme or ebs)"
  default     = "nvme"

  validation {
    condition     = contains(["nvme", "ebs"], var.default_storage_condition)
    error_message = "default_storage_condition must be either \"nvme\" or \"ebs\"."
  }
}

# Runner-side test filter, applied ONCE at coordinator startup
# (extract_testsuites -> get_benchmark_specs) to build the universe of specs
# this runner will ever consider. A trigger's own --tests-regexp can narrow this
# further but can never widen it.
#
# This box exists for storage-sensitive work, so it is pinned to the full-sync /
# persistence family rather than the whole ~490-spec suite. Changing it requires
# a coordinator restart, since the list is built at startup.
variable "tests_regexp" {
  description = "Runner-side spec filter; restricts this runner to storage-driving benchmarks"
  default     = ".*(replica-only|fullsync|full-sync|bgsave|aof|rdb).*"
}

# Only accept work explicitly addressed to this platform. Broadcast full-suite
# triggers carry no target_platform field and are skipped, so this runner never
# gets swept into a fleet-wide run.
variable "explicit_only" {
  description = "Only process stream entries whose target_platform matches this runner (1 = on)"
  default     = "1"
}

variable "coordinator_autostart" {
  description = "Start the coordinator on boot. Default false so a storage qualification in flight cannot be disturbed by queued work."
  default     = "false"
}

variable "event_stream_host" {
  description = "Event stream host for benchmark coordinator"
  default     = ""
}

variable "event_stream_port" {
  description = "Event stream port for benchmark coordinator"
  default     = ""
}

variable "event_stream_user" {
  description = "Event stream user for benchmark coordinator"
  default     = ""
}

variable "event_stream_pass" {
  description = "Event stream password for benchmark coordinator"
  type        = string
  sensitive   = true
  default     = ""
}

variable "datasink_redistimeseries_host" {
  description = "RedisTimeSeries host for data sink"
  default     = ""
}

variable "datasink_redistimeseries_port" {
  description = "RedisTimeSeries port for data sink"
  default     = ""
}

variable "datasink_redistimeseries_pass" {
  description = "RedisTimeSeries password for data sink"
  type        = string
  sensitive   = true
  default     = ""
}

variable "arch" {
  description = "Architecture for the benchmark runner"
  default     = "amd64"
}
