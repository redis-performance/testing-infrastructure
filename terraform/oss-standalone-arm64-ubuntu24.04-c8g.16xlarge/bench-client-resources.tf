
resource "aws_instance" "client" {
  count                  = var.client_instance_count
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  subnet_id              = data.terraform_remote_state.shared_resources.outputs.subnet_public_us_east_2b_id
  vpc_security_group_ids = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name               = var.key_name
  placement_group        = data.terraform_remote_state.shared_resources.outputs.placement_group_name_us_east_2b
  availability_zone      = "us-east-2b"

  # Cloud-init configuration from external file to install and build memtier
  user_data = file("${path.module}/cloud-init-client.yaml")

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  volume_tags = {
    Environment  = "${var.environment}"
    Name         = "ebs_block_device-${var.setup_name}-CLIENT-${count.index + 1}"
    setup        = "${var.setup_name}"
    redis_module = "${var.redis_module}"
    github_actor = "${var.github_actor}"
    github_repo  = "${var.github_repo}"
    github_sha   = "${var.github_sha}"
    timeout_secs = "${var.timeout_secs}"
  }

  tags = {
    Environment  = "${var.environment}"
    Name         = "${var.setup_name}-CLIENT-${count.index + 1}"
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
}
