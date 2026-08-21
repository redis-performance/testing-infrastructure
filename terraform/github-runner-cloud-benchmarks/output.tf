
# Output the public IP address
output "github_runner_public_ip" {
  description = "Public IP of the GitHub Actions runner instance"
  value       = aws_eip.github_runner_eip.public_ip
}