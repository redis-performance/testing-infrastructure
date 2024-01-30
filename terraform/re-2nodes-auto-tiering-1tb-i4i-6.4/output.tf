output "server_public_ip" {
  value = aws_instance.server[*].public_ip
}

output "server_private_ip" {
  value = aws_instance.server[*].private_ip
}

output "server_instance_type" {
  value = var.server_instance_type
}

output "setup_name" {
  value = var.setup_name
}

output "proxy_threads" {
  value = var.proxy_threads
}
