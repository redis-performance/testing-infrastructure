output "server_public_ip" {
  value = ["${aws_instance.server[*].public_ip}"]
}

output "server_private_ip" {
  value = ["${aws_instance.server[*].private_ip}"]
}

output "client_public_ip" {
  value = ["${aws_instance.client[*].public_ip}"]
}

output "client_private_ip" {
  value = ["${aws_instance.client[*].private_ip}"]
}

output "ssh_user" {
  value = "${var.ssh_user}"
}
