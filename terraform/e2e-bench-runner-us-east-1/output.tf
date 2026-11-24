output "instance_id" {
  description = "For Session Manager and the registration command (README)"
  value       = aws_instance.runner.id
}

output "egress_ip" {
  description = "Fixed public address the runners' traffic leaves from"
  value       = aws_eip.runner.public_ip
}

output "registration_parameter" {
  description = "SecureString the registration step reads once and deletes"
  value       = "${local.ssm_prefix}/registration"
}

output "twingate_parameter" {
  description = "SecureString twingate-setup.sh reads once and deletes: the Twingate service key (JSON)"
  value       = "${local.ssm_prefix}/twingate-service-key"
}
