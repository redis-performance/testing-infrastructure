
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    region = "us-east-1"
    key = "testing-infrastructure/terraform/re-2nodes-1dbs-25gb-7.4.0-r6id.2xlarge.tfstate"
  }
}

