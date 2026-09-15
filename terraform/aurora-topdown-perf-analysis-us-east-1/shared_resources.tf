provider "aws" {
  region = var.region
}

# Reference the us-east-1 common infrastructure
data "terraform_remote_state" "us_east_1_common" {
  backend = "s3"
  config = {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/us-east-1-common.tfstate"
    region = "us-east-1"
  }
}

# Also reference the global shared resources (for cross-region access if needed)
data "terraform_remote_state" "shared_resources" {
  backend = "s3"
  config = {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/shared_resources.tfstate"
    region = "us-east-1"
  }
}
