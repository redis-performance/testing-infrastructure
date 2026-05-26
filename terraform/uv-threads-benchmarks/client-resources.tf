resource "aws_instance" "client" {
  ami                    = var.client_instance_ami
  instance_type          = var.client_instance_type
  subnet_id              = data.terraform_remote_state.shared_resources.outputs.subnet_public_us_east_2b_id
  vpc_security_group_ids = ["${data.terraform_remote_state.shared_resources.outputs.performance_cto_sg_id}"]
  key_name               = var.key_name
  placement_group        = data.terraform_remote_state.shared_resources.outputs.placement_group_name_us_east_2b
  availability_zone      = "us-east-2b"

  user_data = file("./client-cloud-init-memtier.yaml") # Use cloud-init to install memtier benchmark

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
    tags = merge(
      local.base_tags,
      {
        Name = "ebs_block_device-${var.setup_name}-CLIENT"
      }
    )
  }

  tags = merge(
    local.base_tags,
    {
      Name         = "${var.setup_name}-CLIENT"
      InstanceType = var.client_instance_type
    }
  )
}
