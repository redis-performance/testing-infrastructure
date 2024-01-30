
output "client_public_ip" {
  value = aws_instance.client[*].public_ip
}

output "client_private_ip" {
  value = aws_instance.client[*].private_ip
}
