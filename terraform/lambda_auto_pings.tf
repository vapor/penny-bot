resource "aws_lambda_function" "auto_pings" {
  function_name = local.lambda_function_names.auto_pings
  s3_bucket     = aws_s3_bucket.lambdas_store.id
  s3_key        = "${local.lambda_function_names.auto_pings}.zip"
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

resource "aws_cloudwatch_log_group" "auto_pings" {
  name              = "/aws/lambda/${local.lambda_function_names.auto_pings}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "auto_pings" {
  statement_id  = "penny-discord-bot-stack-lambdaAutoPingsRoutePermission-160KQ1SUYLIS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_pings.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_integration" "auto_pings" {
  api_id                 = aws_apigatewayv2_api.penny.id
  description            = "Lambda Auto-Pings Integration"
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  connection_type        = "INTERNET"
  integration_uri        = aws_lambda_function.auto_pings.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "auto_pings_all" {
  api_id    = aws_apigatewayv2_api.penny.id
  route_key = "GET /auto-pings/all"
  target    = "integrations/${aws_apigatewayv2_integration.auto_pings.id}"
}

resource "aws_apigatewayv2_route" "auto_pings_add" {
  api_id    = aws_apigatewayv2_api.penny.id
  route_key = "PUT /auto-pings/users"
  target    = "integrations/${aws_apigatewayv2_integration.auto_pings.id}"
}

resource "aws_apigatewayv2_route" "auto_pings_delete" {
  api_id    = aws_apigatewayv2_api.penny.id
  route_key = "DELETE /auto-pings/users"
  target    = "integrations/${aws_apigatewayv2_integration.auto_pings.id}"
}

resource "aws_s3_bucket" "auto_pings_lambda" {
  bucket = "penny-auto-pings-lambda"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "auto_pings_lambda" {
  bucket = aws_s3_bucket.auto_pings_lambda.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_public_access_block" "auto_pings_lambda" {
  bucket                  = aws_s3_bucket.auto_pings_lambda.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "auto_pings_lambda" {
  bucket = aws_s3_bucket.auto_pings_lambda.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "auto_pings_lambda" {
  bucket = aws_s3_bucket.auto_pings_lambda.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "auto_pings_lambda" {
  bucket                                 = aws_s3_bucket.auto_pings_lambda.id
  transition_default_minimum_object_size = "varies_by_storage_class"

  rule {
    id     = "auto-pings-repo.json versioning"
    status = "Enabled"

    filter {
      and {
        prefix                = "auto-pings-repo.json"
        object_size_less_than = 16777216
      }
    }

    noncurrent_version_expiration {
      noncurrent_days           = 30
      newer_noncurrent_versions = 5
    }
  }

  depends_on = [aws_s3_bucket_versioning.auto_pings_lambda]
}
