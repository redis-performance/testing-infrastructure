
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/search-scaling-client-us-east-2.tfstate"
    region = "us-east-1"
  }
}

