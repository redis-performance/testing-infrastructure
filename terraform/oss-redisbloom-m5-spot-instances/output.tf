output "server_public_ip" {
  value = ["${aws_spot_instance_request.server[0].public_ip}"]
}

output "server_private_ip" {
  value = ["${aws_spot_instance_request.server[0].private_ip}"]
}

output "client_public_ip" {
  value = ["${aws_spot_instance_request.client[0].public_ip}"]
}

output "client_private_ip" {
  value = ["${aws_spot_instance_request.client[0].private_ip}"]
}
