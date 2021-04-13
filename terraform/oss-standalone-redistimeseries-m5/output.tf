output "server_public_ip" {
  value = ["${aws_instance.server[0].public_ip}"]
}

output "server_private_ip" {
  value = ["${aws_instance.server[0].private_ip}"]
}

output "client_public_ip" {
  value = ["${aws_instance.client[*].public_ip}"]
}

output "client_private_ip" {
  value = ["${aws_instance.client[*].private_ip}"]
}
