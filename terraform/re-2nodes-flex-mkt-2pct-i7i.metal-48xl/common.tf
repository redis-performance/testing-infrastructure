
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    region = "us-east-1"
    key    = "benchmarks/infrastructure/re-2nodes-flex-mkt-2pct-i7i.metal-48xl.tfstate"
  }

}
