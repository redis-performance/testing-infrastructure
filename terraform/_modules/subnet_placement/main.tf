################################################################################
# Spreads benchmark VMs across shared_infrastructure's subnets instead of
# defaulting everyone onto subnet_public (us-east-2a), whose exhaustion causes
# InsufficientFreeAddressesInSubnet failures under concurrent CI load.
################################################################################

data "terraform_remote_state" "shared_resources" {
  backend = "s3"
  config = {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/shared_resources.tfstate"
    region = "us-east-1"
  }
}

locals {
  candidate_subnet_ids = [
    data.terraform_remote_state.shared_resources.outputs.subnet_public_id,
    data.terraform_remote_state.shared_resources.outputs.subnet_us_east_2b_public_id,
    data.terraform_remote_state.shared_resources.outputs.subnet_us_east_2c_public_id,
  ]
}

data "aws_subnet" "candidates" {
  for_each = toset(local.candidate_subnet_ids)
  id       = each.value
}

locals {
  eligible_subnet_ids = [
    for id in local.candidate_subnet_ids : id
    if data.aws_subnet.candidates[id].available_ip_address_count >= var.min_free_ips
  ]

  # Deterministic hash, not `random_*`: the same placement_key always picks
  # the same subnet within one plan, and a retry after a capacity failure
  # re-evaluates eligibility rather than retrying the exact subnet that just
  # ran out of addresses.
  hash_int    = parseint(substr(md5(var.placement_key), 0, 8), 16)
  selected_id = length(local.eligible_subnet_ids) > 0 ? local.eligible_subnet_ids[local.hash_int % length(local.eligible_subnet_ids)] : null
}
