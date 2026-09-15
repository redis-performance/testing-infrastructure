provider "aws" {
  region = "eu-west-1"
}

# This is the shared resources bucket key -- you will need it across environments
data "terraform_remote_state" "shared_resources" {
  backend = "s3"
  config = {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/shared_resources.tfstate"
    region = "us-east-1"
  }
}

# This is the bucket holding this specific tfstate
terraform {
  backend "s3" {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/github-runner-cloud-benchmarks.tfstate"
    region = "us-east-1"
  }
}
