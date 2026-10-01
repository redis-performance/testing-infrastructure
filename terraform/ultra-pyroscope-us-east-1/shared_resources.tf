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
    key    = "benchmarks/infrastructure/ultra-pyroscope-us-east-1.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# The us-east-1 shared VPC and public subnets (terraform/common-us-east-1). Only the VPC and a subnet are
# used: this module brings its own security group and EIP.
data "terraform_remote_state" "us_east_1_common" {
  backend = "s3"
  config = {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/us-east-1-common.tfstate"
    region = "us-east-1"
  }
}

locals {
  name   = var.setup_name
  bucket = "${var.setup_name}-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name         = var.setup_name
    Environment  = var.environment
    setup        = var.setup_name
    team         = "performance_analysis_optimization"
    owner        = var.github_actor
    github_actor = var.github_actor
    github_repo  = var.github_repo
    github_sha   = var.github_sha
  }
}
