output "endpoint" {
  value = aws_db_instance.db.address
}

output "port" {
  value = aws_db_instance.db.port
}

output "resource_id" {
  description = "For rds-db:connect ARNs"
  value       = aws_db_instance.db.resource_id
}

output "master_secret_arn" {
  description = "Secrets Manager secret with the dbadmin password (one-time role setup only)"
  value       = aws_db_instance.db.master_user_secret[0].secret_arn
}

output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "connect_policy_arns" {
  value = { for k, p in aws_iam_policy.connect : k => p.arn }
}

output "tunnel_command" {
  description = "Forward localhost:15432 to the database (keep it running)"
  value       = "aws ssm start-session --region ${var.region} --target ${aws_instance.bastion.id} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters host=${aws_db_instance.db.address},portNumber=5432,localPortNumber=15432"
}
