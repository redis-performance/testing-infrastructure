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
    key    = "benchmarks/infrastructure/oss-api-us-east-1.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

# Shared by every host in the default VPC (coordinators, builders, this host), so it is looked up, not owned.
data "aws_security_group" "benchmarks" {
  id = var.security_group_id
}

# Created by hand in 2021 and adopted here as-is: the import blocks bring the live resources under state and
# the lifecycle blocks keep Terraform from touching what it did not create (AMI, disk, key pair).
import {
  to = aws_instance.api
  id = "i-0f292e23e1ca09cf4"
}

import {
  to = aws_eip.api
  id = "eipalloc-0985abd710859bfe9"
}

import {
  to = aws_eip_association.api
  id = "eipassoc-00e3f9f8846705086"
}

resource "aws_instance" "api" {
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [data.aws_security_group.benchmarks.id]
  key_name               = var.key_name

  disable_api_termination = true

  root_block_device {
    volume_type = "gp2"
    volume_size = 128
    tags        = { Name = "grafana.benchmarks.redislabs" }
  }

  tags = {
    Name        = "benchmarks.redis watchdog/api"
    Project     = "OSS"
    Environment = "OSS"
    team        = "performance_analysis_optimization"
    owner       = var.owner
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami, user_data, user_data_base64, key_name, root_block_device, ebs_optimized, associate_public_ip_address]
  }
}

# The webhook proxy (terraform/benchmarks_redislabs_infrastructure) forwards to this address, so it must not
# change.
resource "aws_eip" "api" {
  domain = "vpc"

  tags = {
    Name = "EIP.grafana.benchmarks.redislabs"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip_association" "api" {
  instance_id   = aws_instance.api.id
  allocation_id = aws_eip.api.id
}
