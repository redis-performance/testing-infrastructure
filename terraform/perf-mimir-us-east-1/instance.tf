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

  # Mimir runs on the host (no containers), so hop limit 1 is enough for the instance role.
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

  # The bootstrap is idempotent and keeps nothing on the root disk that matters (the TSDB, the WAL and the
  # certificates are on the data volume), so a changed bootstrap replaces the instance.
  user_data_base64 = base64gzip(templatefile("${path.module}/server-init.sh.tftpl", {
    region                     = var.region
    bucket                     = aws_s3_bucket.blocks.id
    mimir_version              = var.mimir_version
    mimir_sha256_amd64         = var.mimir_sha256["amd64"]
    mimir_sha256_arm64         = var.mimir_sha256["arm64"]
    hostname                   = var.hostname
    acme_email                 = var.acme_email
    nginx_channel              = var.nginx_channel
    data_volume                = aws_ebs_volume.data.id
    ssm_prefix                 = local.ssm_prefix
    read_allowed_cidrs         = var.read_allowed_cidrs
    retention_period           = var.retention_period
    max_series_per_tenant      = var.max_series_per_tenant
    ingestion_rate             = var.ingestion_rate
    ingestion_burst_size       = var.ingestion_burst_size
    max_label_names_per_series = var.max_label_names_per_series
    max_label_name_length      = var.max_label_name_length
    max_label_value_length     = var.max_label_value_length
    out_of_order_time_window   = var.out_of_order_time_window
    max_series_total           = var.max_series_total
    max_ingestion_rate_total   = var.max_ingestion_rate_total
    log_group_mimir            = aws_cloudwatch_log_group.mimir.name
    log_group_nginx            = aws_cloudwatch_log_group.nginx.name
    log_group_system           = aws_cloudwatch_log_group.system.name
  }))
  user_data_replace_on_change = true

  tags = local.tags

  # The first boot reads SSM and S3 with the role: let its policies exist first.
  depends_on = [aws_iam_role_policy.server, aws_iam_role_policy_attachment.ssm_core]
}

# The ingester's TSDB (WAL, head, the blocks of the last 13 h), the store-gateway's index headers, compaction
# scratch space and the TLS certificates. It survives instance replacement, so a replaced instance replays the
# WAL and loses nothing. S3 holds every shipped block, so the volume isn't snapshotted: losing it loses at most
# the samples not yet shipped (up to the last 2-3 hours).
resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = var.data_volume_size_gb
  type              = "gp3"
  encrypted         = true
  final_snapshot    = true
  tags              = merge(local.tags, { Name = "${local.name}-data" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "data" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.data.id
  instance_id                    = aws_instance.server.id
  stop_instance_before_detaching = true
}
