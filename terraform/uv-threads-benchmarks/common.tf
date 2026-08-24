
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/uv-threads-benchmarks.tfstate"
    region = "us-east-1"
  }
}
