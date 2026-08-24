output "all_server_public_ips" {
  value = {
    for k, v in var.server_instances_configs : v.name => aws_instance.server[k].public_ip
  }
}

output "all_server_private_ips" {
  value = {
    for k, v in var.server_instances_configs : v.name => aws_instance.server[k].private_ip
  }
}

output "client_public_ip" {
  value = ["${aws_instance.client[*].public_ip}"]
}

output "client_private_ip" {
  value = ["${aws_instance.client[*].private_ip}"]
}
