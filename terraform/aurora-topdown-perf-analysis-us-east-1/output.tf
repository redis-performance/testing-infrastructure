output "cluster_endpoint" {
  value       = module.cluster.cluster_endpoint
  description = "Writer endpoint for the Aurora cluster"
}

output "cluster_reader_endpoint" {
  value       = module.cluster.cluster_reader_endpoint
  description = "Reader endpoint for the Aurora cluster"
}

output "cluster_port" {
  value       = module.cluster.cluster_port
  description = "Port the Aurora cluster is listening on"
}

output "cluster_database_name" {
  value       = module.cluster.cluster_database_name
  description = "Name of the default database"
}

output "cluster_master_username" {
  value       = module.cluster.cluster_master_username
  description = "Master username"
  sensitive   = true
}
