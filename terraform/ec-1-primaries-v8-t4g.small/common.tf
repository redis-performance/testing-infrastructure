
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    region = "us-east-1"
    key = "ec-1-primaries-v8-t4g.small"
  }
}

