# provider
provider "aws" {
  region = "${var.region}"
}

################################################################################
# This is the shared resources bucket key -- you will need it across environments like security rules,etc...
# !! do not change this !!
################################################################################
data "terraform_remote_state" "shared_resources" {
  backend = "s3"
  config = {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/shared_resources.tfstate"
    region = "us-east-1"
  }
}
