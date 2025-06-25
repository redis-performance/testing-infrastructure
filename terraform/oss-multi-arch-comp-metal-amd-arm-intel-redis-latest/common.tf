
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/oss-multi-arch-comp-metal-amd-arm-intel-redis-latest.tfstate"
    region = "us-east-1"
  }
}
