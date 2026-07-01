resource "aws_lambda_function" "auto_faqs" {
  function_name = local.lambda_function_names.auto_faqs
  s3_bucket     = aws_s3_bucket.lambdas_store.id
  s3_key        = "${local.lambda_function_names.auto_faqs}.zip"
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

resource "aws_cloudwatch_log_group" "auto_faqs" {
  name              = "/aws/lambda/${local.lambda_function_names.auto_faqs}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "auto_faqs" {
  statement_id  = "penny-discord-bot-stack-lambdaAutoFaqsRoutePermission-dGTEmVQL3wq7"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_faqs.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_integration" "auto_faqs" {
  api_id                 = aws_apigatewayv2_api.penny.id
  description            = "Lambda Auto Faqs Integration"
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  connection_type        = "INTERNET"
  integration_uri        = aws_lambda_function.auto_faqs.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "auto_faqs" {
  api_id    = aws_apigatewayv2_api.penny.id
  route_key = "POST /auto-faqs"
  target    = "integrations/${aws_apigatewayv2_integration.auto_faqs.id}"
}

resource "aws_s3_bucket" "auto_faqs_lambda" {
  bucket = "penny-auto-faqs-lambda"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "auto_faqs_lambda" {
  bucket = aws_s3_bucket.auto_faqs_lambda.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_public_access_block" "auto_faqs_lambda" {
  bucket                  = aws_s3_bucket.auto_faqs_lambda.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "auto_faqs_lambda" {
  bucket = aws_s3_bucket.auto_faqs_lambda.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
