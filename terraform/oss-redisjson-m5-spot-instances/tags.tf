

locals {

  tags_db = {
    Name           = "${var.setup_name}-DB-1"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    timeout_secs   = "${var.timeout_secs}"
    Environment    = "${var.environment}"
    Project        = "${var.environment}"
  }

  tags_client = {
    Name           = "${var.setup_name}-CLIENT-1"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    timeout_secs   = "${var.timeout_secs}"
    Environment    = "${var.environment}"
    Project        = "${var.environment}"
  }
}

resource "aws_ec2_tag" "server" {
  resource_id = aws_spot_instance_request.server[0].spot_instance_id
  for_each    = local.tags_db
  key         = each.key
  value       = each.value
}


resource "aws_ec2_tag" "client" {
  resource_id = aws_spot_instance_request.client[0].spot_instance_id
  for_each    = local.tags_client
  key         = each.key
  value       = each.value
}
