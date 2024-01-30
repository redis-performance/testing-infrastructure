output "server_public_ip" {
  value = aws_instance.server_2a[*].public_ip
}

output "server_private_ip" {
  value = aws_instance.server_2a[*].private_ip
}

output "server_instance_type" {
  value = var.server_instance_type
}

# output "client_public_ip" {
#   value = aws_instance.client[0].public_ip
# }


output "search_threads" {
  value = var.search_thread
}
