
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/oss-multi-arch-comp-amd-arm-intel-4xlarge-redis-7.2-redis-8.0.0.tfstate"
    region = "us-east-1"
  }
}
