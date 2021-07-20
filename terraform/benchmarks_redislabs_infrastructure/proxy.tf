resource "aws_eip_association" "proxy_eip_assoc" {
  instance_id   = "${aws_instance.proxy_instance[0].id}"
  allocation_id = data.terraform_remote_state.shared_resources.outputs.benchmarks_redislabs_eip_id
}

resource "aws_instance" "proxy_instance" {
  disable_api_termination              = true
  count                  = "${var.server_instance_count}"
  ami                    = "${var.instance_ami}"
  instance_type          = "${var.instance_type}"
  subnet_id              = data.terraform_remote_state.shared_resources.outputs.subnet_public_id
  vpc_security_group_ids = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name               = "${var.key_name_proxy}"
  cpu_core_count         = "${var.instance_cpu_core_count}"

  cpu_threads_per_core = "${var.instance_cpu_threads_per_core_hyperthreading}"
  placement_group      = "${data.terraform_remote_state.shared_resources.outputs.perf_cto_pg_name}"


  volume_tags = {
    Name = "ebs_block_device-benchmarks.redislabs.com-PROXY-${count.index + 1}"
  }

  tags = {
    Name = "benchmarks.redislabs.com-PROXY-${count.index + 1}"
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
      timeout = "5m"
      agent   = "false"
    }
  }
}
