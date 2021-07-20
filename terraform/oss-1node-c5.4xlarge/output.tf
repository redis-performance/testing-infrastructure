output "server_public_ips" {
  value = ["${aws_instance.server[*].public_ip}"]
}

output "server_private_ips" {
  value = ["${aws_instance.server[*].private_ip}"]
}
