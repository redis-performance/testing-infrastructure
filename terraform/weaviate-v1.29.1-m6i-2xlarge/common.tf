
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    region = "us-east-1"
    key = "weaviate-v1.29.1-m6i-2xlarge.tfstate"
  }
}

