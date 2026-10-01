# Profiles live here (Pyroscope v2 writes straight to object storage). The metastore index is on the EBS
# volume; its raft snapshots are also copied here under backups/ (see the user-data).
resource "aws_s3_bucket" "profiles" {
  bucket = local.bucket
  tags   = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "profiles" {
  bucket = aws_s3_bucket.profiles.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "profiles" {
  bucket                  = aws_s3_bucket.profiles.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "profiles" {
  bucket = aws_s3_bucket.profiles.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning protects against an accidental purge. Compaction deletes constantly, so old versions expire
# after 45 days (longer than the 30 days of hourly metastore snapshots, so the objects a restored index
# points at still exist as noncurrent versions; the runbook in README.md restores them).
resource "aws_s3_bucket_versioning" "profiles" {
  bucket = aws_s3_bucket.profiles.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Never expire current objects here: retention is Pyroscope's (-retention-period), which keeps its index
# consistent.
resource "aws_s3_bucket_lifecycle_configuration" "profiles" {
  bucket     = aws_s3_bucket.profiles.id
  depends_on = [aws_s3_bucket_versioning.profiles]

  rule {
    id     = "old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 45
    }
    expiration {
      expired_object_delete_marker = true
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Raft snapshot copies (backups/): kept 30 days, like the hourly EBS snapshots.
  rule {
    id     = "raft-snapshot-backups"
    status = "Enabled"
    filter {
      prefix = "backups/"
    }
    expiration {
      days = 30
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  # The profiles are Redis Confidential: object access only for the server and the account admins (SSO
  # AdministratorAccess). Bucket-level actions stay open to IAM, so Terraform can't lock itself out.
  statement {
    sid       = "ObjectsServerAndAdminsOnly"
    effect    = "Deny"
    actions   = ["s3:GetObject*", "s3:PutObject*", "s3:DeleteObject*", "s3:RestoreObject"]
    resources = ["${aws_s3_bucket.profiles.arn}/*"]
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
    resources = [aws_s3_bucket.profiles.arn, "${aws_s3_bucket.profiles.arn}/*"]
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

resource "aws_s3_bucket_policy" "profiles" {
  bucket     = aws_s3_bucket.profiles.id
  policy     = data.aws_iam_policy_document.bucket.json
  depends_on = [aws_s3_bucket_public_access_block.profiles]
}
