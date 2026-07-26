resource "aws_s3_bucket" "this" {
  bucket = var.name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
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
  count = var.versioning_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.lifecycle_rule == null ? 0 : 1

  bucket                                 = aws_s3_bucket.this.id
  transition_default_minimum_object_size = "varies_by_storage_class"

  rule {
    id     = var.lifecycle_rule.id
    status = "Enabled"

    filter {
      and {
        prefix                = var.lifecycle_rule.prefix
        object_size_less_than = var.lifecycle_rule.object_size_less_than
      }
    }

    noncurrent_version_expiration {
      noncurrent_days           = var.lifecycle_rule.noncurrent_days
      newer_noncurrent_versions = var.lifecycle_rule.newer_noncurrent_versions
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
