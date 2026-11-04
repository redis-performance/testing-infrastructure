output "public_ip" {
  description = "Create the A record for the hostname -> this IP (cto.redislabs.com zone, CTO account)"
  value       = aws_eip.server.public_ip
}

output "url" {
  value = "https://${var.hostname}"
}

output "push_url" {
  description = "Prometheus remote_write endpoint"
  value       = "https://${var.hostname}/api/v1/push"
}

output "query_url" {
  description = "Grafana Prometheus datasource URL (reads only from read_allowed_cidrs)"
  value       = "https://${var.hostname}/prometheus"
}

output "instance_id" {
  value = aws_instance.server.id
}

output "bucket" {
  value = aws_s3_bucket.blocks.id
}

output "data_volume_id" {
  value = aws_ebs_volume.data.id
}

output "credential_parameters" {
  description = "SSM SecureString parameters to create before the server can authenticate anyone (htpasswd lines, <tenant>-<role>-<1|2>)"
  value       = ["${local.ssm_prefix}/htpasswd/push", "${local.ssm_prefix}/htpasswd/read"]
}

output "alarm_topic_arn" {
  value = aws_sns_topic.alarms.arn
}
