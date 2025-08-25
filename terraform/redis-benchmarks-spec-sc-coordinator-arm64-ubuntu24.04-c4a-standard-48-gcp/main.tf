# Redis Benchmarks Spec SC Coordinator - GCP C4A Axion ARM64 Ubuntu 24.04

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/redis-benchmarks-spec-sc-coordinator-arm64-ubuntu24.04-c4a-standard-48-gcp.tfstate"
    region = "us-east-1"
  }
}

# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Data source for getting the latest Ubuntu 24.04 LTS ARM64 image
data "google_compute_image" "ubuntu_arm64" {
  family  = "ubuntu-2404-lts-arm64"
  project = "ubuntu-os-cloud"
}

# Create a VPC network if one doesn't exist
resource "google_compute_network" "benchmark_network" {
  count                   = var.create_network ? 1 : 0
  name                    = "${var.deployment_name}-network"
  auto_create_subnetworks = false
  description             = "Network for Redis benchmark coordinator"
}

# Create a subnet
resource "google_compute_subnetwork" "benchmark_subnet" {
  count         = var.create_network ? 1 : 0
  name          = "${var.deployment_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.benchmark_network[0].id
  description   = "Subnet for Redis benchmark coordinator"
}

# Firewall rules for benchmark coordinator
resource "google_compute_firewall" "benchmark_firewall" {
  count   = var.create_network ? 1 : 0
  name    = "${var.deployment_name}-firewall"
  network = google_compute_network.benchmark_network[0].name

  allow {
    protocol = "tcp"
    ports    = ["22", "6379", "8080", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = var.allowed_source_ranges
  target_tags   = ["benchmark-coordinator"]
  description   = "Firewall rules for Redis benchmark coordinator"
}

# External IP address
resource "google_compute_address" "benchmark_ip" {
  count        = var.create_external_ip ? 1 : 0
  name         = "${var.deployment_name}-ip"
  region       = var.region
  address_type = "EXTERNAL"
  description  = "External IP for Redis benchmark coordinator"
}

# Hyperdisk for additional storage
resource "google_compute_disk" "benchmark_disk" {
  count = var.additional_disk_size > 0 ? 1 : 0
  name  = "${var.deployment_name}-disk"
  type  = var.disk_type
  zone  = var.zone
  size  = var.additional_disk_size

  labels = {
    environment = var.environment
    purpose     = "benchmark-storage"
  }
}

# External data source for environment variables
data "external" "env" {
  program = ["${path.module}/env.sh"]
}

# Locals for effective values (environment variables take precedence over Terraform variables)
locals {
  event_stream_host_eff = length(trimspace(try(data.external.env.result.event_stream_host, ""))) > 0 ? data.external.env.result.event_stream_host : var.event_stream_host
  event_stream_port_eff = length(trimspace(try(data.external.env.result.event_stream_port, ""))) > 0 ? data.external.env.result.event_stream_port : var.event_stream_port
  event_stream_user_eff = length(trimspace(try(data.external.env.result.event_stream_user, ""))) > 0 ? data.external.env.result.event_stream_user : var.event_stream_user
  event_stream_pass_eff = length(trimspace(try(data.external.env.result.event_stream_pass, ""))) > 0 ? data.external.env.result.event_stream_pass : var.event_stream_pass

  datasink_rts_host_eff = length(trimspace(try(data.external.env.result.datasink_redistimeseries_host, ""))) > 0 ? data.external.env.result.datasink_redistimeseries_host : var.datasink_redistimeseries_host
  datasink_rts_port_eff = length(trimspace(try(data.external.env.result.datasink_redistimeseries_port, ""))) > 0 ? data.external.env.result.datasink_redistimeseries_port : var.datasink_redistimeseries_port
  datasink_rts_pass_eff = length(trimspace(try(data.external.env.result.datasink_redistimeseries_pass, ""))) > 0 ? data.external.env.result.datasink_redistimeseries_pass : var.datasink_redistimeseries_pass
}

# Cloud-init configuration
locals {
  cloud_init_config = templatefile("${path.module}/cloud-init.yaml", {
    platform_name                    = var.platform_name
    event_stream_host                = local.event_stream_host_eff
    event_stream_port                = local.event_stream_port_eff
    event_stream_user                = local.event_stream_user_eff
    event_stream_pass                = local.event_stream_pass_eff
    datasink_redistimeseries_host    = local.datasink_rts_host_eff
    datasink_redistimeseries_port    = local.datasink_rts_port_eff
    datasink_redistimeseries_pass    = local.datasink_rts_pass_eff
    arch                            = "arm64"
    timeout_secs                    = var.timeout_secs
  })
}

# Main compute instance
resource "google_compute_instance" "benchmark_coordinator" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["benchmark-coordinator"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_arm64.self_link
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  # Attach additional disk if specified
  dynamic "attached_disk" {
    for_each = var.additional_disk_size > 0 ? [1] : []
    content {
      source      = google_compute_disk.benchmark_disk[0].id
      device_name = "benchmark-data"
    }
  }

  network_interface {
    network    = var.create_network ? google_compute_network.benchmark_network[0].id : var.network_name
    subnetwork = var.create_network ? google_compute_subnetwork.benchmark_subnet[0].id : var.subnetwork_name

    dynamic "access_config" {
      for_each = var.create_external_ip ? [1] : []
      content {
        nat_ip = google_compute_address.benchmark_ip[0].address
      }
    }
  }

  # Enable gVNIC for optimal C4A performance
  network_performance_config {
    total_egress_bandwidth_tier = var.enable_tier1_networking ? "TIER_1" : "DEFAULT"
  }

  metadata = {
    user-data = local.cloud_init_config
    ssh-keys  = var.ssh_public_key != "" ? "${var.ssh_user}:${var.ssh_public_key}" : ""
  }

  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }

  labels = {
    environment = var.environment
    purpose     = "redis-benchmark-coordinator"
    arch        = "arm64"
    machine     = "c4a-axion"
  }

  # Lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  # Startup script for additional configuration
  metadata_startup_script = var.startup_script

  # Enable deletion protection if specified
  deletion_protection = var.deletion_protection
}

# Watchdog timer for automatic cleanup
resource "google_compute_instance_template" "watchdog_template" {
  count = var.enable_watchdog ? 1 : 0
  name  = "${var.deployment_name}-watchdog-template"

  machine_type = "e2-micro"
  region       = var.region

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = var.create_network ? google_compute_network.benchmark_network[0].id : var.network_name
  }

  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      sleep ${var.timeout_secs}
      gcloud compute instances delete ${var.instance_name} --zone=${var.zone} --quiet
    EOF
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/compute"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
