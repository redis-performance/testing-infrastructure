output "server_1_public_ip" {
  value = [aws_instance.server_1.public_ip]
}

output "server_1_private_ip" {
  value = [aws_instance.server_1.private_ip,aws_network_interface.additional_eni_1.private_ip]
}

output "server_2_public_ip" {
  value = [aws_instance.server_2.public_ip]
}

output "server_2_private_ip" {
  value = [aws_instance.server_2.private_ip,aws_network_interface.additional_eni_2.private_ip]
}

output "server_instance_type" {
  value = var.server_instance_type
}
