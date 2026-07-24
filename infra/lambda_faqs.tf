resource "aws_lambda_function" "faqs" {
  function_name = local.lambda_function_names.faqs
  s3_bucket     = aws_s3_bucket.lambdas_store.id
  s3_key        = "${local.lambda_function_names.faqs}.zip"
  role          = aws_iam_role.lambda.arn
  handler       = "handler"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  memory_size   = 256
  timeout       = 20

  lifecycle {
    ignore_changes = [s3_bucket, s3_key]
  }
}

resource "aws_cloudwatch_log_group" "faqs" {
  name              = "/aws/lambda/${local.lambda_function_names.faqs}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "faqs" {
  statement_id  = "penny-discord-bot-stack-lambdaFaqsRoutePermission-HKD57ZUYTGT2"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.faqs.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_integration" "faqs" {
  api_id                 = aws_apigatewayv2_api.penny.id
  description            = "Lambda Faqs Integration"
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  connection_type        = "INTERNET"
  integration_uri        = aws_lambda_function.faqs.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "faqs" {
  api_id    = aws_apigatewayv2_api.penny.id
  route_key = "POST /faqs"
  target    = "integrations/${aws_apigatewayv2_integration.faqs.id}"
}

resource "aws_s3_bucket" "faqs_lambda" {
  bucket = "penny-faqs-lambda"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "faqs_lambda" {
  bucket = aws_s3_bucket.faqs_lambda.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_public_access_block" "faqs_lambda" {
  bucket                  = aws_s3_bucket.faqs_lambda.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "faqs_lambda" {
  bucket = aws_s3_bucket.faqs_lambda.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "faqs_lambda" {
  bucket = aws_s3_bucket.faqs_lambda.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "faqs_lambda" {
  bucket                                 = aws_s3_bucket.faqs_lambda.id
  transition_default_minimum_object_size = "varies_by_storage_class"

  rule {
    id     = "faqs-repo.json versioning"
    status = "Enabled"

    filter {
      and {
        prefix                = "faqs-repo.json"
        object_size_less_than = 33554432
      }
    }

    noncurrent_version_expiration {
      noncurrent_days           = 30
      newer_noncurrent_versions = 5
    }
  }

  depends_on = [aws_s3_bucket_versioning.faqs_lambda]
}
