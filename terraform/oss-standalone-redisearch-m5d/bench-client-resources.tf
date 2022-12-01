resource "aws_default_subnet" "default_subnet" {
  availability_zone = "us-east-2a"

}

resource "aws_default_vpc" "default" {
}

resource "aws_security_group" "perf_test" {
  name        = "perf_test"
  description = "perf_test"
  vpc_id      = "${aws_default_vpc.default.id}"

#  ingress {
#    description      = "TLS from VPC"
#    from_port        = 0
#    to_port          = 0
#    protocol         = "tcp"
#    security_groups = ["${aws_security_group.perf_test.id}"]
#  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "perf_test"
  }
}

resource "aws_security_group_rule" "main_ingress_rule" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "tcp"
  source_security_group_id = "${aws_security_group.perf_test.id}"
  security_group_id = "${aws_security_group.perf_test.id}"
}

resource "aws_security_group_rule" "debug_ssh" {
  type              = "ingress"
  from_port         = 0
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks = ["213.159.37.109/32"]
  security_group_id = "${aws_security_group.perf_test.id}"
}


resource "aws_instance" "client" {
  count                  = "${var.client_instance_count}"
  ami                    = "${var.instance_ami}"
  instance_type          = "${var.client_instance_type}"
  subnet_id              = "${aws_default_subnet.default_subnet.id}"
#  vpc_security_group_ids = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  security_groups        = ["${aws_security_group.perf_test.id}"]
  key_name               = "${var.key_name}"
  associate_public_ip_address = "true"
#  placement_group      = "${data.terraform_remote_state.shared_resources.outputs.perf_cto_pg_name}"
  availability_zone = "us-east-2a"

  root_block_device {
    volume_size           = "${var.instance_volume_size}"
    volume_type           = "${var.instance_volume_type}"
    encrypted             = "${var.instance_volume_encrypted}"
    delete_on_termination = true
  }

  volume_tags = {
    Name        = "ebs_block_device-${var.setup_name}-CLIENT-${count.index + 1}"
    setup        = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor = "${var.github_actor}"
    github_org = "${var.github_org}"
    github_repo  = "${var.github_repo}"
    github_sha   = "${var.github_sha}"
    timeout_secs = "${var.timeout_secs}"
  }

  tags = {
    Name         = "${var.setup_name}-CLIENT-${count.index + 1}"
    setup        = "${var.setup_name}"
    triggering_env = "${var.triggering_env}"
    github_actor = "${var.github_actor}"
    github_org = "${var.github_org}"
    github_repo  = "${var.github_repo}"
    github_sha   = "${var.github_sha}"
    timeout_secs = "${var.timeout_secs}"
  }

  ################################################################################
  # This will ensure we wait here until the instance is ready to receive the ssh connection 
  ################################################################################
  provisioner "remote-exec" {
    script = "./../scripts/wait_for_instance.sh"
    connection {
      host        = "${self.public_ip}" # The `self` variable is like `this` in many programming languages
      type        = "ssh"               # in this case, `self` is the resource (the server).
      user        = "${var.ssh_user}"
      private_key = "${file(var.private_key_path)}"
      #need to increase timeout to larger then 5m for metal instances
      timeout = "5m"
      agent   = "false"
    }
  }

  ################################################################################
  # Deployment related
  ################################################################################
}
