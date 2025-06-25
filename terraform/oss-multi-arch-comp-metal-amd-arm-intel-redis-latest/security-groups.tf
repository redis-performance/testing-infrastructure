# Security group that allows SSH from internet and all traffic from local VPC
resource "aws_security_group" "ssh_only" {
  name_prefix = "${var.setup_name}-ssh-only-"
  description = "Security group allowing SSH from internet and all traffic from local VPC"
  vpc_id      = data.terraform_remote_state.shared_resources.outputs.performance_cto_vpc_id

  # SSH access from anywhere
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic from within the VPC
  ingress {
    description = "All internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.3.0.0/16"] # Allow VPC traffic
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.base_tags,
    {
      Name = "${var.setup_name}-ssh-only-sg"
    }
  )
}
