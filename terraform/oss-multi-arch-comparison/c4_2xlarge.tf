
resource "aws_instance" "c4_2xlarge" {
  count                       = var.db_instance_count
  ami                         = var.instance_ami
  instance_type               = "c4.2xlarge"
  subnet_id                   = data.terraform_remote_state.shared_resources.outputs.subnet_public_id
  vpc_security_group_ids      = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name                    = var.key_name
  associate_public_ip_address = "true"
  availability_zone           = "us-east-2a"


  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  volume_tags = {
    Name           = "ebs_block_device-${var.setup_name}-c4.2xlarge"
    setup          = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
    timeout_secs   = "${var.timeout_secs}"
  }

  tags = {
    Name           = "${var.setup_name}-c4.2xlarge"
    triggering_env = "${var.triggering_env}"
    github_actor   = "${var.github_actor}"
    github_org     = "${var.github_org}"
    github_repo    = "${var.github_repo}"
    github_sha     = "${var.github_sha}"
  }
}