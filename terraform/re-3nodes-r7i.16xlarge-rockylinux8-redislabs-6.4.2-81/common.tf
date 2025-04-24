
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    region = "us-east-1"
    key = "re-3nodes-r7i.16xlarge-rockylinux8-redislabs-6.4.2-81.tfstate"
  }
}

