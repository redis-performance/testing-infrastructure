
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/redis-benchmarks-spec-sc-coordinator-amd64-ubuntu24.04-m7i.metal-24xl-1.tfstate"
    region = "us-east-1"
  }
}

# This is a data source, so it will run at plan time.
data "external" "env" {
  program = ["${path.module}/env.sh"]
}
