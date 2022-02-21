
################################################################################
# This is the bucket holding this specific setup tfstate
################################################################################
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/oss-k8s-milvus-1node-m6i.tfstate"
    region = "us-east-1"
  }
}

