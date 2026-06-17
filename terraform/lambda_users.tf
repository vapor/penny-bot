resource "aws_lambda_function" "users" {
  function_name = local.lambda_function_names.users
  s3_bucket     = aws_s3_bucket.lambdas_store.id
  s3_key        = "${local.lambda_function_names.users}.zip"
  role          = aws_iam_role.lambda.arn
  handler       = "handler"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  memory_size   = 256
  timeout       = 20

  environment {
    variables = {
      API_BASE_URL = local.api_base_url
      LOG_LEVEL    = "debug"
    }
  }

  lifecycle {
    ignore_changes = [s3_bucket, s3_key]
  }
}

resource "aws_cloudwatch_log_group" "users" {
  name              = "/aws/lambda/${local.lambda_function_names.users}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "users" {
  statement_id  = "penny-discord-bot-stack-lambdaUsersRoutePermission-X2F3NQYIUTN7"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.users.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_integration" "users" {
  api_id                 = aws_apigatewayv2_api.penny.id
  description            = "Lambda Users Integration"
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  connection_type        = "INTERNET"
  integration_uri        = aws_lambda_function.users.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "users" {
  api_id    = aws_apigatewayv2_api.penny.id
  route_key = "POST /users"
  target    = "integrations/${aws_apigatewayv2_integration.users.id}"
}
