
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    region = "us-east-1"
    key = "bench-client-ubuntu24.04-c7i.4xlarge.tfstate"
  }
}

