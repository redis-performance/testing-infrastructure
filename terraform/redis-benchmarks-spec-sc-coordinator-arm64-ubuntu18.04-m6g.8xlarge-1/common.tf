
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/redis-benchmarks-spec-sc-coordinator-arm64-ubuntu18.04-m6g.8xlarge-1.tfstate"
    region = "us-east-1"
  }
}

