output "server_public_ip" {
  value = ["${aws_instance.server[*].public_ip}"]
}

output "server_private_ip" {
  value = ["${aws_instance.server[*].private_ip}"]
}

output "client_public_ip" {
  value = ["${aws_instance.client[0].public_ip}"]
}

output "client_private_ip" {
  value = ["${aws_instance.client[0].private_ip}"]
}
