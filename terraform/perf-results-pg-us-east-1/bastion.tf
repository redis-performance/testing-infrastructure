# A Session Manager endpoint for port forwarding to the database: no SSH, no key pair, no inbound rule.
# Workstations run AWS-StartPortForwardingSessionToRemoteHost against it (README).
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${local.name}-bastion"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# AmazonSSMManagedInstanceCore allows ssm:GetParameter(s) on every parameter in the account; the bastion
# needs none.
data "aws_iam_policy_document" "bastion_deny_parameters" {
  statement {
    effect    = "Deny"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath", "ssm:GetParameterHistory"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "bastion_deny_parameters" {
  name   = "${local.name}-bastion-deny-parameters"
  role   = aws_iam_role.bastion.id
  policy = data.aws_iam_policy_document.bastion_deny_parameters.json
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.name}-bastion"
  role = aws_iam_role.bastion.name
  tags = local.tags
}

# Amazon Linux 2023 ships the SSM agent. The AMI is read once: a newer image does not replace the bastion.
data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023_arm64.insecure_value
  instance_type               = var.bastion_instance_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true # outbound to the SSM endpoints through the internet gateway
  disable_api_termination     = true
  force_destroy               = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
    tags        = merge(local.tags, { Name = "${local.name}-bastion-root" })
  }

  tags = merge(local.tags, { Name = "${local.name}-bastion" })

  lifecycle {
    ignore_changes = [ami, subnet_id]
  }

  depends_on = [aws_iam_role_policy_attachment.bastion_ssm]
}
