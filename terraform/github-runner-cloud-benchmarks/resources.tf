# Reference the remote state from common-eu-west-1 subdirectory
data "terraform_remote_state" "eu_west_1_common" {
  backend = "s3"
  config = {
    bucket = "performance-cto-group"
    key    = "benchmarks/infrastructure/eu-west-1-common.tfstate"
    region = "us-east-1"
  }
}

# Create the EC2 instance for GitHub runner
resource "aws_instance" "github_runner_instance" {
  ami                         = "ami-095c0fee0e8a3c88d" # Ubuntu 24.04 LTS (eu-west-1)
  instance_type               = "m7i.8xlarge"
  subnet_id                   = data.terraform_remote_state.eu_west_1_common.outputs.github_runner_subnet_id
  vpc_security_group_ids       = [data.terraform_remote_state.eu_west_1_common.outputs.github_runner_sg_id]
  key_name                    = "benchmarks-eu-west-1"

  root_block_device {
    volume_size           = var.instance_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "github-runner"

    Environment = "cloud-benchmarks"
     Project = "cloud-benchmarks"
    team           = "performance a&o"
  }
}

# Create an Elastic IP for the instance
resource "aws_eip" "github_runner_eip" {
  instance = aws_instance.github_runner_instance.id
  domain   = "vpc"

  tags = {
    Name = "github-runner-eip"

    Environment = "cloud-benchmarks"
     Project = "cloud-benchmarks"
  }
}
