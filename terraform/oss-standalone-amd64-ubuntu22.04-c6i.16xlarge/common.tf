
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/oss-standalone-amd64-ubuntu22.04-c6i.16xlarge.tfstate"
    region = "us-east-1"
  }
}

