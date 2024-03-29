
resource "aws_instance" "client" {
  count                  = var.client_instance_count
  ami                    = var.client_instance_ami
  instance_type          = var.client_instance_type
  subnet_id              = data.terraform_remote_state.shared_resources.outputs.subnet_public_id
  vpc_security_group_ids = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name               = var.key_name
  availability_zone      = "us-east-2a"

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  volume_tags = {
    Environment    = "${var.environment}"
    Project        = "${var.environment}"
    Name           = "ebs_block_device-${var.setup_name}-CLIENT-us-east-2a-${count.index + 1}"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
  }

  tags = {
    Environment    = "${var.environment}"
    Project        = "${var.environment}"
    Name           = "${var.setup_name}-CLIENT-us-east-2a-${count.index + 1}"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
  }

  ################################################################################
  # Deployment related
  ################################################################################
}
