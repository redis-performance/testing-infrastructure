output "public_ip" {
  description = "Create the A record for the hostname -> this IP (cto.redislabs.com zone, CTO account)"
  value       = aws_eip.server.public_ip
}

output "url" {
  value = "https://${var.hostname}"
}

output "instance_id" {
  value = aws_instance.server.id
}

output "bucket" {
  value = aws_s3_bucket.profiles.id
}

output "credential_parameters" {
  description = "SSM SecureString parameters to create before the server can authenticate anyone (htpasswd lines)"
  value       = ["/${local.name}/htpasswd/push", "/${local.name}/htpasswd/read"]
}

output "alarm_topic_arn" {
  value = aws_sns_topic.alarms.arn
}
