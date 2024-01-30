output "server_public_ip" {
  value = ["${aws_instance.server_2a[*].public_ip}", "${aws_instance.server_2b[*].public_ip}"]
}

output "server_private_ip" {
  value = ["${aws_instance.server_2a[*].private_ip}", "${aws_instance.server_2b[*].private_ip}"]
}
