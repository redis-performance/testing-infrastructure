output "server_public_ip" {
  value = ["${aws_instance.server[0].public_ip}"]
}

output "server_private_ip" {
  value = ["${aws_instance.server[0].private_ip}"]
}

output "platform_name_nvme" {
  description = "Platform name to target for the local-NVMe condition"
  value       = "${var.platform_name_base}-nvme"
}

output "platform_name_ebs" {
  description = "Platform name to target for the dedicated-EBS condition"
  value       = "${var.platform_name_base}-ebs"
}
