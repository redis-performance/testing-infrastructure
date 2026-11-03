output "server_public_ip" {
  value = aws_instance.server_2a[*].public_ip
}

output "server_private_ip" {
  value = aws_instance.server_2a[*].private_ip
}

output "server_instance_type" {
  value = var.server_instance_type
}

output "db_endpoint" {
  value       = length(aws_instance.server_2a) > 0 ? "${aws_instance.server_2a[0].private_ip}:${var.db_port}" : ""
  description = "Redis Enterprise database endpoint (private IP:port)"
}

output "db_port" {
  value       = var.db_port
  description = "Redis Enterprise database port"
}

output "shard_count" {
  value       = var.shard_count
  description = "Number of shards in the Redis database"
}

output "db_config" {
  value = {
    endpoint                      = length(aws_instance.server_2a) > 0 ? "${aws_instance.server_2a[0].private_ip}:${var.db_port}" : ""
    port                          = var.db_port
    shard_count                   = var.shard_count
    memory_size                   = var.memory_size
    oss_cluster                   = var.oss_cluster
    replication                   = var.replication
    redis_version                 = var.redis_version
    shards_placement              = var.shards_placement
    data_persistence              = var.data_persistence
    tls_mode                      = var.tls_mode
    enforce_client_authentication = var.enforce_client_authentication
  }
  description = "Complete Redis Enterprise database configuration"
}

output "client_public_ip" {
  value = aws_instance.client[*].public_ip
}

output "client_private_ip" {
  value = aws_instance.client[*].private_ip
}

output "client_instance_type" {
  value = var.client_instance_type
}

output "network_tuning" {
  value = {
    rx_usecs    = var.rx_usecs
    tx_usecs    = var.tx_usecs
    adaptive_rx = var.adaptive_rx
  }
  description = "Network interface interrupt coalescing configuration"
}
