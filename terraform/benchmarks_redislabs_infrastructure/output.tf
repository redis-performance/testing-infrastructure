
output "monitoring_instance_prometheus" {
  value = ["${aws_instance.monitoring_instance[0].public_ip}:9090"]
}

output "monitoring_instance_grafana" {
  value = ["${aws_instance.monitoring_instance[0].public_ip}:3000"]
}

output "proxy_instance_eip" {
  value = ["${aws_instance.proxy_instance[0].public_ip}"]
}
