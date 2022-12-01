output "runner_public_ip" {
  value = ["${aws_instance.runner[0].public_ip}"]
}

output "runner_private_ip" {
  value = ["${aws_instance.runner[0].private_ip}"]
}
