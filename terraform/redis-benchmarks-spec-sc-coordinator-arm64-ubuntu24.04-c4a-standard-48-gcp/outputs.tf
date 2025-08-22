# Redis Benchmarks Spec SC Coordinator - GCP C4A Outputs

################################################################################
# Instance Information
################################################################################
output "instance_name" {
  description = "Name of the created instance"
  value       = google_compute_instance.benchmark_coordinator.name
}

output "instance_id" {
  description = "ID of the created instance"
  value       = google_compute_instance.benchmark_coordinator.id
}

output "instance_self_link" {
  description = "Self link of the created instance"
  value       = google_compute_instance.benchmark_coordinator.self_link
}

output "machine_type" {
  description = "Machine type of the instance"
  value       = google_compute_instance.benchmark_coordinator.machine_type
}

output "zone" {
  description = "Zone where the instance is located"
  value       = google_compute_instance.benchmark_coordinator.zone
}

################################################################################
# Network Information
################################################################################
output "internal_ip" {
  description = "Internal IP address of the instance"
  value       = google_compute_instance.benchmark_coordinator.network_interface[0].network_ip
}

output "external_ip" {
  description = "External IP address of the instance"
  value       = var.create_external_ip ? google_compute_address.benchmark_ip[0].address : ""
}

output "network_name" {
  description = "Name of the network"
  value       = var.create_network ? google_compute_network.benchmark_network[0].name : var.network_name
}

output "subnetwork_name" {
  description = "Name of the subnetwork"
  value       = var.create_network ? google_compute_subnetwork.benchmark_subnet[0].name : var.subnetwork_name
}

################################################################################
# SSH Connection Information
################################################################################
output "ssh_command" {
  description = "SSH command to connect to the instance"
  value = var.create_external_ip ? "ssh ${var.ssh_user}@${google_compute_address.benchmark_ip[0].address}" : "ssh ${var.ssh_user}@${google_compute_instance.benchmark_coordinator.network_interface[0].network_ip}"
}

################################################################################
# Benchmark Configuration
################################################################################
output "platform_name" {
  description = "Platform name used for benchmarking"
  value       = var.platform_name
}

output "architecture" {
  description = "Instance architecture"
  value       = var.arch
}

output "operating_system" {
  description = "Operating system"
  value       = var.os
}

################################################################################
# Storage Information
################################################################################
output "boot_disk_size" {
  description = "Boot disk size in GB"
  value       = var.boot_disk_size
}

output "boot_disk_type" {
  description = "Boot disk type"
  value       = var.boot_disk_type
}

output "additional_disk_attached" {
  description = "Whether an additional disk is attached"
  value       = var.additional_disk_size > 0
}

output "additional_disk_size" {
  description = "Additional disk size in GB"
  value       = var.additional_disk_size
}

################################################################################
# Performance Configuration
################################################################################
output "tier1_networking_enabled" {
  description = "Whether Tier 1 networking is enabled"
  value       = var.enable_tier1_networking
}

output "max_network_bandwidth" {
  description = "Maximum network bandwidth"
  value       = var.enable_tier1_networking ? "100 Gbps" : "50 Gbps"
}

################################################################################
# Resource URLs for Management
################################################################################
output "instance_console_url" {
  description = "URL to view the instance in Google Cloud Console"
  value       = "https://console.cloud.google.com/compute/instancesDetail/zones/${google_compute_instance.benchmark_coordinator.zone}/instances/${google_compute_instance.benchmark_coordinator.name}?project=${var.project_id}"
}

output "logs_url" {
  description = "URL to view instance logs in Google Cloud Console"
  value       = "https://console.cloud.google.com/logs/query;query=resource.type%3D%22gce_instance%22%0Aresource.labels.instance_id%3D%22${google_compute_instance.benchmark_coordinator.instance_id}%22?project=${var.project_id}"
}

################################################################################
# Deployment Information
################################################################################
output "deployment_summary" {
  description = "Summary of the deployment"
  value = {
    instance_name     = google_compute_instance.benchmark_coordinator.name
    machine_type      = google_compute_instance.benchmark_coordinator.machine_type
    zone             = google_compute_instance.benchmark_coordinator.zone
    internal_ip      = google_compute_instance.benchmark_coordinator.network_interface[0].network_ip
    external_ip      = var.create_external_ip ? google_compute_address.benchmark_ip[0].address : "none"
    platform_name    = var.platform_name
    architecture     = var.arch
    os              = var.os
    tier1_networking = var.enable_tier1_networking
    watchdog_enabled = var.enable_watchdog
    timeout_secs     = var.timeout_secs
  }
}
