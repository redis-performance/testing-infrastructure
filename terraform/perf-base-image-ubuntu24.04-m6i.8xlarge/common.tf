
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    region = "us-east-1"
    key = "benchmarks/infrastructure/perf-base-image-ubuntu24.04-m6i.8xlarge-redis-8.4.tfstate"

  }
}

