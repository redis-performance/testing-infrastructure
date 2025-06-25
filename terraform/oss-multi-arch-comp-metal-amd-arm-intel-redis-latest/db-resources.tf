resource "aws_instance" "server" {
  for_each               = var.server_instances_configs # Create instances for each architecture
  ami                    = each.value.ami
  instance_type          = each.value.instance_type
  subnet_id              = data.terraform_remote_state.shared_resources.outputs.subnet_public_us_east_2b_id
  vpc_security_group_ids = [aws_security_group.ssh_only.id]
  key_name               = var.key_name
  placement_group        = data.terraform_remote_state.shared_resources.outputs.placement_group_name_us_east_2b
  availability_zone      = "us-east-2b"

  user_data = file("./db-cloud-init-dbs.yaml") # Use cloud-init to install Redis versions

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = var.instance_volume_type
    encrypted             = var.instance_volume_encrypted
    delete_on_termination = true
    tags = merge(
      local.base_tags,
      {
        Name = "ebs_block_device-${var.setup_name}-${each.value.arch_label}"
      }
    )
  }

  tags = merge(
    local.base_tags,
    {
      Name         = "${var.setup_name}-${each.value.arch_label}"
      Architecture = each.value.arch_label
      InstanceType = each.value.instance_type
    }
  )
}
