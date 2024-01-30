
output "consumer_public_ips" {
  value = aws_instance.consumer[*].public_ip
}

output "producer_public_ips" {
  value = aws_instance.producer[*].public_ip
}

output "server_instance_type" {
  value = var.server_instance_type
}

output "server_ssh_user" {
  value = var.ssh_user
}

output "setup_name" {
  value = var.setup_name
}
