output "server_public_ip" {
  value = aws_instance.server_2a[*].public_ip
}

output "server_private_ip" {
  value = aws_instance.server_2a[*].private_ip
}

output "server_instance_type" {
  value = var.server_instance_type
}


output "ami_id" {
  value = aws_ami_from_instance.perf_ami.id
}
