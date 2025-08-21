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

  # Cloud-init user data for benchmark runner setup
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    platform_name                    = var.platform_name
    event_stream_host                = local.event_stream_host_eff
    event_stream_port                = local.event_stream_port_eff
    event_stream_user                = local.event_stream_user_eff
    event_stream_pass                = local.event_stream_pass_eff
    datasink_redistimeseries_host    = local.datasink_rts_host_eff
    datasink_redistimeseries_port    = local.datasink_rts_port_eff
    datasink_redistimeseries_pass    = local.datasink_rts_pass_eff
    arch                              = var.arch
  })

  # Replace the instance if user_data changes so cloud-init re-runs on first boot
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
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
  }

  ################################################################################
  # This will ensure we wait here until the instance is ready to receive the ssh connection
  ################################################################################
  provisioner "remote-exec" {
    script = "./../../scripts/wait_for_instance.sh"
    connection {
      host        = self.public_ip # The `self` variable is like `this` in many programming languages
      type        = "ssh"          # in this case, `self` is the resource (the server).
      user        = var.ssh_user
      private_key = file(var.private_key)
      #need to increase timeout to larger then 5m for metal instances
      timeout = "15m"
      agent   = "false"
    }
  }

  ################################################################################
  # Deployment related
  ################################################################################
}
