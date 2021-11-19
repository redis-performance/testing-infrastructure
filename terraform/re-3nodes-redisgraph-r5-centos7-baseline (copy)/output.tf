output "server_public_ip" {
  value = ["${aws_instance.server[*].public_ip}"]
}

output "server_private_ip" {
  value = ["${aws_instance.server[*].private_ip}"]
}
