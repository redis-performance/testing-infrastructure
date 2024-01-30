
output "server_public_ip" {
  value = aws_instance.server[*].public_ip
}

output "server_private_ip" {
  value = aws_instance.server[*].private_ip
}

output "server_instance_type" {
  value = var.server_instance_type
}


output "server_ssh_user" {
  value = var.ssh_user
}
