# Its own security group: 443 for pushes from the Neptune cells (whose NAT IPs change every run, so
# nginx credentials, not source IPs, gate pushes) and for the Grafana reads (nginx also allowlists their
# source); 80 only for the Let's Encrypt HTTP-01 challenge and a redirect. No SSH: SSM only.
resource "aws_security_group" "server" {
  name        = "${local.name}-server"
  description = "Pyroscope server: HTTPS in, all out"
  vpc_id      = data.terraform_remote_state.us_east_1_common.outputs.perf_cto_vpc_id
  tags        = local.tags

  ingress {
    description = "HTTPS (nginx: per-role credentials and path allowlist)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP: Lets Encrypt HTTP-01 challenge and a redirect only"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# The A record (outside this module) points here; released, the IP could be taken by someone who'd then
# pass the Let's Encrypt challenge for the name.
resource "aws_eip" "server" {
  domain = "vpc"
  tags   = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip_association" "server" {
  instance_id   = aws_instance.server.id
  allocation_id = aws_eip.server.id
}
