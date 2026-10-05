# No ingress at all: runners only dial out (GitHub, AWS APIs, package mirrors), and administration is
# Session Manager.
resource "aws_security_group" "runner" {
  name        = "${local.name}-host"
  description = "${local.name}: egress only"
  vpc_id      = data.terraform_remote_state.us_east_1_common.outputs.perf_cto_vpc_id
  tags        = local.tags
}

resource "aws_vpc_security_group_egress_rule" "all_v4" {
  security_group_id = aws_security_group.runner.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags              = local.tags
}

# A fixed egress address, so services that allow-list callers can name this host.
resource "aws_eip" "runner" {
  domain = "vpc"
  tags   = local.tags
}

resource "aws_eip_association" "runner" {
  instance_id   = aws_instance.runner.id
  allocation_id = aws_eip.runner.id
}
