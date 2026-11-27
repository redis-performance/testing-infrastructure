# The database: 5432 from the bastion (SSM port forwarding for workstations) and from the client groups
# (benchmark VMs). Nothing from the internet: the instance is not publicly accessible.
resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "PostgreSQL from the bastion and the benchmark VMs only"
  vpc_id      = data.aws_vpc.default.id
  tags        = merge(local.tags, { Name = "${local.name}-db" })
}

resource "aws_vpc_security_group_ingress_rule" "db_from_bastion" {
  security_group_id            = aws_security_group.db.id
  description                  = "SSM port forwarding through the bastion"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.bastion.id
  tags                         = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "db_from_clients" {
  for_each                     = toset(var.client_security_group_ids)
  security_group_id            = aws_security_group.db.id
  description                  = "Benchmark VMs"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = each.value
  tags                         = local.tags
}

# The bastion takes no inbound traffic at all: Session Manager connects outbound from the SSM agent.
resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion"
  description = "SSM-only bastion: no inbound, all out"
  vpc_id      = data.aws_vpc.default.id
  tags        = merge(local.tags, { Name = "${local.name}-bastion" })
}

resource "aws_vpc_security_group_egress_rule" "bastion_out" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSM endpoints and the database"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags              = local.tags
}
