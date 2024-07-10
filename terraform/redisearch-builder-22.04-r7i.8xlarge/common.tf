
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    region = "us-east-1"
    key = "benchmarks/infrastructure/re-builder-22.04-r7i.8xlarge.tfstate"
  }
}

