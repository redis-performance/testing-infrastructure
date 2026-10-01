locals {
  subnet_id = {
    "us-east-1a" = data.terraform_remote_state.us_east_1_common.outputs.subnet_us_east_1a_id
    "us-east-1b" = data.terraform_remote_state.us_east_1_common.outputs.subnet_us_east_1b_id
  }[var.availability_zone]
}

resource "aws_instance" "server" {
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.server.id]
  iam_instance_profile   = aws_iam_instance_profile.server.name
  # Protection against the console, the CLI and the repo's idle-VM watchdog; force_destroy lets Terraform
  # lift it when it replaces the instance (provider 6.x only does that with force_destroy).
  disable_api_termination = true
  force_destroy           = true

  # Pyroscope runs with host networking, so the instance role is reachable at hop limit 1.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size_gb
    encrypted   = true
    tags        = merge(local.tags, { Name = "${local.name}-root" })
  }

  # The bootstrap is idempotent and keeps no state on the root disk that matters (the metastore and the
  # certificates are on the metastore volume), so a changed bootstrap replaces the instance.
  user_data_base64 = base64gzip(templatefile("${path.module}/server-init.sh.tftpl", {
    region             = var.region
    bucket             = aws_s3_bucket.profiles.id
    image              = var.pyroscope_image
    hostname           = var.hostname
    acme_email         = var.acme_email
    nginx_channel      = var.nginx_channel
    retention_period   = var.retention_period
    metastore_volume   = aws_ebs_volume.metastore.id
    ssm_prefix         = "/${local.name}"
    read_allowed_cidrs = var.read_allowed_cidrs
    log_group_pyro     = aws_cloudwatch_log_group.pyroscope.name
    log_group_nginx    = aws_cloudwatch_log_group.nginx.name
    log_group_system   = aws_cloudwatch_log_group.system.name
  }))
  user_data_replace_on_change = true

  tags = local.tags

  # The first boot reads SSM and S3 with the role: let its policies exist first.
  depends_on = [aws_iam_role_policy.server, aws_iam_role_policy_attachment.ssm_core]
}

# The only stateful part of Pyroscope v2 (raft log, snapshots, index), plus the TLS certificates. It
# survives instance replacement; v2 can't rebuild its index from S3, so it's protected and snapshotted.
resource "aws_ebs_volume" "metastore" {
  availability_zone = var.availability_zone
  size              = var.metastore_volume_size_gb
  type              = "gp3"
  encrypted         = true
  final_snapshot    = true
  tags              = merge(local.tags, { Name = "${local.name}-metastore", "${local.name}-snapshot" = "hourly" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "metastore" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.metastore.id
  instance_id                    = aws_instance.server.id
  stop_instance_before_detaching = true
}

resource "aws_dlm_lifecycle_policy" "metastore" {
  description        = "${local.name} metastore hourly snapshots"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"
  tags               = local.tags

  policy_details {
    resource_types = ["VOLUME"]
    target_tags    = { "${local.name}-snapshot" = "hourly" }

    schedule {
      name = "hourly-30d"
      create_rule {
        interval      = 1
        interval_unit = "HOURS"
      }
      retain_rule {
        count = 720
      }
      # Not the target tag: a volume restored from a snapshot with its tags would be snapshotted twice.
      copy_tags   = false
      tags_to_add = merge(local.tags, { Name = "${local.name}-metastore" })
    }
  }
}
