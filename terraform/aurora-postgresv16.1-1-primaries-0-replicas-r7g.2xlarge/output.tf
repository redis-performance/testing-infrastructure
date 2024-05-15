
output "primary_endpoint_address" {
  sensitive = true
  value = ["${module.cluster}"]
}
