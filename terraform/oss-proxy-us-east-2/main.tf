terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.39.0"
    }
  }
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/oss-proxy-us-east-2.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

# Shared by every host in the us-east-2 VPC (managed in terraform/common), so it is looked up, not owned.
data "aws_security_group" "perf_cto" {
  id = var.security_group_id
}

# Replacement for benchmarks.redislabs.com-PROXY-1 (terraform/benchmarks_redislabs_infrastructure), which is
# Ubuntu 16.04 with HAProxy 1.8. Built side by side so every backend can be checked before the EIP moves
# (README). No EIP here on purpose: the cutover is a deliberate, separate step.
resource "aws_instance" "proxy" {
  ami                         = var.instance_ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [data.aws_security_group.perf_cto.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  disable_api_termination     = true
  force_destroy               = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size_gb
    encrypted   = true
    tags        = { Name = "ebs_block_device-${var.setup_name}" }
  }

  tags = {
    Name        = var.setup_name
    Project     = "Common"
    Environment = "Common"
    team        = "performance_analysis_optimization"
    owner       = var.owner
  }

  lifecycle {
    ignore_changes = [ami, user_data, user_data_base64]
  }
}

# benchmarks-redislabs-eip (18.116.150.197): the address the webhook, the RTS endpoints and the spec bucket
# are reached on. Moved here from terraform/benchmarks_redislabs_infrastructure at the PROXY-1 -> PROXY-2
# cutover. Rollback: associate the same allocation with PROXY-1 (i-0413b2ea2e7b3583f), see README.
resource "aws_eip_association" "proxy" {
  instance_id         = aws_instance.proxy.id
  allocation_id       = var.proxy_eip_allocation_id
  allow_reassociation = true
}
