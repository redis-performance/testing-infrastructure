output "subnet_id" {
  value = local.selected_id
  precondition {
    condition     = local.selected_id != null
    error_message = "No shared subnet has >= ${var.min_free_ips} free IPs (checked subnet_public_id, subnet_us_east_2b_public_id, subnet_us_east_2c_public_id from shared_resources). Free up capacity or lower min_free_ips."
  }
}

output "availability_zone" {
  value = local.selected_id != null ? data.aws_subnet.candidates[local.selected_id].availability_zone : null
}
