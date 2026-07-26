resource "aws_s3_bucket" "lambdas_store" {
  bucket = "penny-lambdas-store"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambdas_store" {
  bucket = aws_s3_bucket.lambdas_store.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_public_access_block" "lambdas_store" {
  bucket                  = aws_s3_bucket.lambdas_store.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "lambdas_store" {
  bucket = aws_s3_bucket.lambdas_store.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
