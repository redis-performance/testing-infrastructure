locals {
  subnet_id = {
    "us-east-1a" = data.terraform_remote_state.us_east_1_common.outputs.subnet_us_east_1a_id
    "us-east-1b" = data.terraform_remote_state.us_east_1_common.outputs.subnet_us_east_1b_id
  }[var.availability_zone]
}

resource "aws_instance" "runner" {
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.runner.id]
  iam_instance_profile   = aws_iam_instance_profile.runner.name
  # Idle between runs by design: protected against the console, the CLI and the repo's idle-VM watchdog.
  # force_destroy lets Terraform lift the protection when it replaces the instance.
  disable_api_termination = true
  force_destroy           = true

  # Jobs run on the host, so keep the instance role behind IMDSv2 at hop limit 1 (no container hop).
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size_gb
    encrypted   = true
    tags        = merge(local.tags, { Name = "${local.name}-root" })
  }

  # Installs the tools and runner_count unregistered runners at first boot; registration is a separate
  # step (README), so no GitHub credential is ever in user data or state.
  user_data_base64 = base64gzip(templatefile("${path.module}/runner-init.sh.tftpl", {
    region         = var.region
    ssm_prefix     = local.ssm_prefix
    runner_count   = var.runner_count
    runner_version = var.runner_version
    runner_sha256  = var.runner_sha256
  }))
  # A bootstrap, AMI or runner_count change does NOT replace the host on its own: jobs can run for days,
  # and a replacement drops every registered runner. Replace deliberately (README):
  #   terraform apply -replace=aws_instance.runner
  user_data_replace_on_change = false
  lifecycle {
    ignore_changes = [user_data_base64, ami]
  }

  tags = local.tags

  depends_on = [aws_iam_role_policy.runner, aws_iam_role_policy_attachment.ssm_core]
}
