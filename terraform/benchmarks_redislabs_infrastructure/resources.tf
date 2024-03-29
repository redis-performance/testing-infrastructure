#providers
provider "aws" {
  region = var.region
}

# This is the shared resources bucket key -- you will need it across environments
data "terraform_remote_state" "shared_resources" {
  backend = "s3"
  config = {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/shared_resources.tfstate"
    region = "us-east-1"
  }
}

# This is the bucket holding this specific tfstate
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/monitoring-infrastructure.tfstate"
    region = "us-east-1"
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.monitoring_instance[0].id
  allocation_id = data.terraform_remote_state.shared_resources.outputs.perf_cto_eip_id
}

resource "aws_instance" "monitoring_instance" {
  disable_api_termination = true
  count                   = var.server_instance_count
  ami                     = var.instance_ami
  instance_type           = var.instance_type
  subnet_id               = data.terraform_remote_state.shared_resources.outputs.subnet_public_id
  vpc_security_group_ids  = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name                = var.key_name
  cpu_core_count          = var.instance_cpu_core_count

  cpu_threads_per_core = var.instance_cpu_threads_per_core_hyperthreading
  placement_group      = data.terraform_remote_state.shared_resources.outputs.perf_cto_pg_name


  volume_tags = {
    Environment = "${var.environment}"
    Name        = "ebs_block_device-${var.setup_name}-${count.index + 1}"
    RedisModule = "${var.redis_module}"
  }

  tags = {
    Environment = "${var.environment}"
    Name        = "${var.setup_name}-${count.index + 1}"
    RedisModule = "${var.redis_module}"
  }


  # Ansible requires Python to be installed on the remote machine as well as the local machine.
  provisioner "remote-exec" {
    inline = ["sudo apt install python -y"]
    connection {
      host        = self.public_ip # The `self` variable is like `this` in many programming languages
      type        = "ssh"          # in this case, `self` is the resource (the server).
      user        = var.ssh_user
      private_key = file(var.private_key)
    }
  }

  ##############
  # Prometheus #
  ##############
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.ssh_user} --private-key ${var.private_key} ../../playbooks/${var.os}/prometheus.yml -i ${self.public_ip},"
  }

  ###########
  # Grafana #
  ###########
  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.ssh_user} --private-key ${var.private_key} ../../playbooks/${var.os}/grafana.yml -i ${self.public_ip}, --extra-vars \"prometheus_web_listen_address=${data.terraform_remote_state.shared_resources.outputs.perf_cto_eip_public_ip}:9090\""
  }

}
