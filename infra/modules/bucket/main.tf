resource "aws_s3_bucket" "this" {
  bucket = var.name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = var.object_ownership
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

moved {
  from = aws_s3_bucket_versioning.this[0]
  to   = aws_s3_bucket_versioning.this
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = length(var.lifecycle_rules) == 0 ? 0 : 1

  bucket                                 = aws_s3_bucket.this.id
  transition_default_minimum_object_size = "varies_by_storage_class"

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      id     = rule.key
      status = "Enabled"

      filter {
        and {
          prefix                = rule.value.prefix
          object_size_less_than = rule.value.object_size_less_than
        }
      }

      noncurrent_version_expiration {
        noncurrent_days           = rule.value.noncurrent_days
        newer_noncurrent_versions = rule.value.newer_noncurrent_versions
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
