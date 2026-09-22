locals {
  event_stream_host_eff = length(trimspace(try(data.external.env.result.event_stream_host, ""))) > 0 ? data.external.env.result.event_stream_host : var.event_stream_host
  event_stream_port_eff = length(trimspace(try(data.external.env.result.event_stream_port, ""))) > 0 ? data.external.env.result.event_stream_port : var.event_stream_port
  event_stream_user_eff = length(trimspace(try(data.external.env.result.event_stream_user, ""))) > 0 ? data.external.env.result.event_stream_user : var.event_stream_user
  event_stream_pass_eff = length(trimspace(try(data.external.env.result.event_stream_pass, ""))) > 0 ? data.external.env.result.event_stream_pass : var.event_stream_pass

  datasink_rts_host_eff = length(trimspace(try(data.external.env.result.datasink_redistimeseries_host, ""))) > 0 ? data.external.env.result.datasink_redistimeseries_host : var.datasink_redistimeseries_host
  datasink_rts_port_eff = length(trimspace(try(data.external.env.result.datasink_redistimeseries_port, ""))) > 0 ? data.external.env.result.datasink_redistimeseries_port : var.datasink_redistimeseries_port
  datasink_rts_pass_eff = length(trimspace(try(data.external.env.result.datasink_redistimeseries_pass, ""))) > 0 ? data.external.env.result.datasink_redistimeseries_pass : var.datasink_redistimeseries_pass
}

resource "aws_instance" "server" {
  count                  = var.server_instance_count
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  subnet_id              = "subnet-e85eb4c2"
  vpc_security_group_ids = ["sg-046d72511dd949d2b"]
  key_name               = var.key_name

  # gzip+base64: the rendered cloud-config is ~20 KB with both scripts embedded,
  # over EC2's 16384-byte user_data cap. cloud-init decompresses gzipped
  # user-data natively, so this needs no fetch-at-boot step and keeps the
  # scripts self-contained in the AMI-independent user_data.
  user_data_base64 = base64gzip(templatefile("${path.module}/cloud-init.yaml", {
    platform_name_base            = var.platform_name_base
    default_storage_condition     = var.default_storage_condition
    tests_regexp                  = var.tests_regexp
    explicit_only                 = var.explicit_only
    coordinator_autostart         = var.coordinator_autostart
    runner_user                   = var.ssh_user
    event_stream_host             = local.event_stream_host_eff
    event_stream_port             = local.event_stream_port_eff
    event_stream_user             = local.event_stream_user_eff
    event_stream_pass             = local.event_stream_pass_eff
    datasink_redistimeseries_host = local.datasink_rts_host_eff
    datasink_redistimeseries_port = local.datasink_rts_port_eff
    datasink_redistimeseries_pass = local.datasink_rts_pass_eff
    arch                          = var.arch

    # Base64 so templatefile() cannot touch the shell parameter expansion the
    # scripts rely on.
    prepare_storage_b64             = filebase64("${path.module}/prepare_storage.sh")
    benchmark_storage_condition_b64 = filebase64("${path.module}/benchmark-storage-condition.sh")
  }))

  # Replace the instance if user_data changes so cloud-init re-runs on first boot
  user_data_replace_on_change = true

  # Bare-metal instances routinely exceed the provider's 10-minute default for
  # reaching "running" -- an i8g.metal-24xl timed out at 10m while the instance
  # itself came up healthy, leaving terraform to fail a create that had actually
  # succeeded.
  timeouts {
    create = "30m"
    delete = "30m"
  }

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  ################################################################################
  # Dedicated EBS benchmark-data volume.
  #
  # Declared inline rather than as a separate aws_ebs_volume + attachment so the
  # device is present at FIRST BOOT. prepare_storage.sh runs from cloud-init and
  # hard-fails if this volume is missing; a late attachment would race it.
  ################################################################################
  ebs_block_device {
    device_name           = var.ebs_data_device_name
    volume_size           = var.ebs_data_volume_size
    volume_type           = var.ebs_data_volume_type
    iops                  = var.ebs_data_volume_iops
    throughput            = var.ebs_data_volume_throughput
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  volume_tags = {
    Environment  = "${var.environment}"
    Name         = "ebs_block_device-${var.setup_name}-${count.index + 1}"
    setup        = "${var.setup_name}"
    redis_module = "${var.redis_module}"
    github_actor = "${var.github_actor}"
    github_repo  = "${var.github_repo}"
    github_sha   = "${var.github_sha}"
    timeout_secs = "${var.timeout_secs}"
    team         = "performance_analysis_optimization"
    owner        = "${var.github_actor}"
  }

  tags = {
    Environment  = "${var.environment}"
    Name         = "${var.setup_name}-${count.index + 1}"
    setup        = "${var.setup_name}"
    redis_module = "${var.redis_module}"
    github_actor = "${var.github_actor}"
    github_repo  = "${var.github_repo}"
    github_sha   = "${var.github_sha}"
    timeout_secs = "${var.timeout_secs}"
    team         = "performance_analysis_optimization"
    owner        = "${var.github_actor}"
  }

  ################################################################################
  # This will ensure we wait here until the instance is ready to receive the ssh connection
  ################################################################################
  provisioner "remote-exec" {
    script = "./../../scripts/wait_for_instance.sh"
    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      #need to increase timeout to larger then 5m for metal instances
      timeout = "15m"
      agent   = "false"
    }
  }
}
