resource "aws_spot_instance_request" "server" {
  count                = var.server_instance_count
  wait_for_fulfillment = true
  spot_type            = "one-time"
  ami                  = var.instance_ami
  instance_type        = var.server_instance_type

  subnet_id                   = data.terraform_remote_state.shared_resources.outputs.subnet_public_id
  vpc_security_group_ids      = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name                    = var.key_name
  associate_public_ip_address = "true"
  placement_group             = data.terraform_remote_state.shared_resources.outputs.perf_cto_pg_name
  availability_zone           = "us-east-2a"

  cpu_options {
    core_count       = var.server_instance_cpu_core_count
    threads_per_core = var.server_instance_cpu_threads_per_core
  }

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  volume_tags = {
    Environment    = "${var.environment}"
    Name           = "ebs_block_device-${var.setup_name}-DB-${count.index + 1}"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    timeout_secs   = "${var.timeout_secs}"
  }

  tags = {
    Environment    = "${var.environment}"
    Name           = "${var.setup_name}-DB-${count.index + 1}"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    timeout_secs   = "${var.timeout_secs}"
  }

  ################################################################################
  # This will ensure we wait here until the instance is ready to receive the ssh connection 
  ################################################################################
  provisioner "remote-exec" {
    script = "./../scripts/wait_for_instance.sh"
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
