data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runner" {
  name               = "${local.name}-host"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = local.tags
}

# Session Manager, plus read-and-delete of this host's own registration parameter. Jobs on the host can
# reach this role through IMDS, so it holds nothing else: workflows bring their own AWS credentials
# (GitHub OIDC). The explicit Deny keeps AmazonSSMManagedInstanceCore's account-wide ssm:GetParameter(s)
# off every other parameter.
data "aws_iam_policy_document" "runner" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:DeleteParameter"]
    resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*"]
  }
  statement {
    effect        = "Deny"
    actions       = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath", "ssm:GetParameterHistory"]
    not_resources = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "runner" {
  name   = "${local.name}-host"
  role   = aws_iam_role.runner.id
  policy = data.aws_iam_policy_document.runner.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "runner" {
  name = "${local.name}-host"
  role = aws_iam_role.runner.name
  tags = local.tags
}
