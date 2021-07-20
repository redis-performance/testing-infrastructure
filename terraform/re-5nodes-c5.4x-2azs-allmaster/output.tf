output "az1_server_public_ip" {
  value = ["${aws_instance.az1_server[*].public_ip}"]
}

output "az1_server_private_ip" {
  value = ["${aws_instance.az1_server[*].private_ip}"]
}

output "az2_server_public_ip" {
  value = ["${aws_instance.az2_server[*].public_ip}"]
}

output "az2_server_private_ip" {
  value = ["${aws_instance.az2_server[*].private_ip}"]
}


output "az2_client_public_ip" {
  value = ["${aws_instance.az2_client[*].public_ip}"]
}

output "az1_client_public_ip" {
  value = ["${aws_instance.az1_client[*].public_ip}"]
}
