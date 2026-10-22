# Mimir's object storage: the TSDB blocks of every tenant (blocks/<tenant>/…) and the ruler's rule groups
# (ruler/…). The ingesters ship a block every 2 hours; the compactor merges them into 24 h blocks and, with
# retention_period = 0, never deletes them. Only the last couple of hours live on the instance alone.
resource "aws_s3_bucket" "blocks" {
  bucket = local.bucket
  tags   = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "blocks" {
  bucket = aws_s3_bucket.blocks.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "blocks" {
  bucket                  = aws_s3_bucket.blocks.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "blocks" {
  bucket = aws_s3_bucket.blocks.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning protects against an accidental purge (a mistaken retention_period, a bucket cleanup). The
# compactor deletes its source blocks after every merge, so old versions expire after 30 days: long enough
# to notice and undo a mistake (README.md, "Undelete blocks").
resource "aws_s3_bucket_versioning" "blocks" {
  bucket = aws_s3_bucket.blocks.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Never expire current objects here: retention is Mimir's (the compactor), which keeps its bucket index
# consistent.
resource "aws_s3_bucket_lifecycle_configuration" "blocks" {
  bucket     = aws_s3_bucket.blocks.id
  depends_on = [aws_s3_bucket_versioning.blocks]

  rule {
    id     = "old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    expiration {
      expired_object_delete_marker = true
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  # Object access only for the server and the account admins (SSO AdministratorAccess). Bucket-level actions
  # stay open to IAM, so Terraform can't lock itself out.
  statement {
    sid       = "ObjectsServerAndAdminsOnly"
    effect    = "Deny"
    actions   = ["s3:GetObject*", "s3:PutObject*", "s3:DeleteObject*", "s3:RestoreObject"]
    resources = ["${aws_s3_bucket.blocks.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotLike"
      variable = "aws:PrincipalArn"
      values = [
        aws_iam_role.server.arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_*",
      ]
    }
  }
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.blocks.arn, "${aws_s3_bucket.blocks.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "blocks" {
  bucket     = aws_s3_bucket.blocks.id
  policy     = data.aws_iam_policy_document.bucket.json
  depends_on = [aws_s3_bucket_public_access_block.blocks]
}
