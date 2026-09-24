variable "placement_key" {
  description = <<-EOT
    Identity to spread placement across subnets. Pass var.setup_name from the
    calling root module. Must be unique per concurrently-running `terraform
    apply` (see redisbench-admin's `--setup_name_sufix`) -- reusing the same
    key across concurrent applies defeats the spreading, since they all pick
    the same subnet.
  EOT
  type        = string
}

variable "min_free_ips" {
  description = "Minimum free IPs a subnet must have to be considered a placement candidate."
  type        = number
  default     = 8
}
