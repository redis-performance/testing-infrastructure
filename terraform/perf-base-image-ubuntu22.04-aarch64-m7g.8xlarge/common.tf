
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    region = "us-east-1"
    key = "benchmarks/infrastructure/perf-base-image-ubuntu22.04-aarch64-m7g.8xlarge.tfstate"

  }
}

