
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    region = "us-east-1"
    key    = "benchmarks/infrastructure/jammy-22.04-amd64-server-20250305-m7a.2xlarge.tfstate"
  }
}

