output "client_public_ip" {
  value = ["${aws_instance.client[*].public_ip}"]
}

output "server_public_ip" {
  value = ["${aws_instance.cluster1_server[*].public_ip}"]
}

output "server_private_ip" {
  value = ["${aws_instance.cluster1_server[*].private_ip}"]
}

output "cluster1_server_public_ip" {
  value = ["${aws_instance.cluster1_server[*].public_ip}"]
}

output "cluster1_server_private_ip" {
  value = ["${aws_instance.cluster1_server[*].private_ip}"]
}

output "cluster2_server_public_ip" {
  value = ["${aws_instance.cluster2_server[*].public_ip}"]
}

output "cluster2_server_private_ip" {
  value = ["${aws_instance.cluster2_server[*].private_ip}"]
}
