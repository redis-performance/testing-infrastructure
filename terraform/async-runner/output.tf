output "runner_public_ip" {
  value = ["${aws_instance.runner.public_ip}"]
}

output "runner_private_ip" {
  value = ["${aws_instance.runner.private_ip}"]
}
