# IAM database authentication for the two database roles the README creates once: "writer" (ingest) and
# "reader" (queries). Attach these policies to whatever runs as those roles (a CI OIDC role, an instance
# role). Account administrators already have rds-db:connect.
data "aws_iam_policy_document" "connect" {
  for_each = toset(["reader", "writer"])
  statement {
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.db.resource_id}/${each.key}"]
  }
}

resource "aws_iam_policy" "connect" {
  for_each    = toset(["reader", "writer"])
  name        = "${local.name}-connect-${each.key}"
  description = "IAM authentication to ${local.name} as ${each.key}"
  policy      = data.aws_iam_policy_document.connect[each.key].json
  tags        = local.tags
}
