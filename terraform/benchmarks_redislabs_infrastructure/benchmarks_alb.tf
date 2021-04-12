
resource "aws_globalaccelerator_accelerator" "benchmarks_redislabs_ga" {
  name            = "Example"
  ip_address_type = "IPV4"
  enabled         = true
}