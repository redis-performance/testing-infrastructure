
resource "aws_spot_instance_request" "client" {
  wait_for_fulfillment        = true
  spot_type                   = "one-time"
  count                       = var.client_instance_count
  ami                         = var.instance_ami
  instance_type               = var.client_instance_type
  subnet_id                   = data.terraform_remote_state.shared_resources.outputs.subnet_public_id
  vpc_security_group_ids      = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name                    = var.key_name
  associate_public_ip_address = "true"
  placement_group             = data.terraform_remote_state.shared_resources.outputs.perf_cto_pg_name
  availability_zone           = "us-east-2a"

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
  }

  ################################################################################
  # This will ensure we wait here until the instance is ready to receive the ssh connection 
  ################################################################################
  user_data = <<-EOF
    #!/bin/bash
    echo "Instance is ready" > /var/log/instance_ready.log
  EOF

  ################################################################################
  # Deployment related
  ################################################################################
}
