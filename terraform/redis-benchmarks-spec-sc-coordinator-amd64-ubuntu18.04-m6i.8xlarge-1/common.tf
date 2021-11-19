
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/redis-benchmarks-spec-sc-coordinator-amd64-ubuntu18.04-m6i.8xlarge-1.tfstate"
    region = "us-east-1"
  }
}

