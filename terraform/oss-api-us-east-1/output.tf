output "api_public_ip" {
  description = "Target of the HAProxy webhook backend on the proxy host (benchmarks_redislabs_infrastructure), port 35000"
  value       = aws_eip.api.public_ip
}

output "api_instance_id" {
  value = aws_instance.api.id
}
