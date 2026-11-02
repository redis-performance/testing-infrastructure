output "proxy_instance_id" {
  value = aws_instance.proxy.id
}

output "proxy_public_ip" {
  description = "Temporary: the instance's auto-assigned public IP, until the PROXY-1 EIP is moved here"
  value       = aws_instance.proxy.public_ip
}

output "proxy_private_ip" {
  value = aws_instance.proxy.private_ip
}
