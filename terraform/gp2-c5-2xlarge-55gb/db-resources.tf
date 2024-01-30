
resource "aws_instance" "server" {
  count                  = var.server_instance_count
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  subnet_id              = "subnet-e85eb4c2"
  vpc_security_group_ids = ["sg-046d72511dd949d2b"]
  key_name               = var.key_name

  ebs_block_device {
    device_name = var.instance_device_name
    volume_size = var.instance_volume_size
    #iops                  = var.instance_volume_iops
    #throughput            = var.instance_volume_throughput
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
