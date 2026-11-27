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
    key    = "benchmarks/infrastructure/perf-results-pg-us-east-1.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# The account's default VPC, not terraform/common-us-east-1: the benchmark VMs that write results run there
# (public subnets, the CTO team security group), and the database must be reachable from them without a
# public endpoint.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

locals {
  name = var.setup_name
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
