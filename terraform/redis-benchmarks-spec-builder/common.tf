
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/redis-benchmarks-spec-builder.tfstate"
    region = "us-east-1"
  }
}

