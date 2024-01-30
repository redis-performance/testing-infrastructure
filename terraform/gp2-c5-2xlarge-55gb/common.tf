
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/gp2-c5-2xlarge-55gb.tfstate"
    region = "us-east-1"
  }
}

