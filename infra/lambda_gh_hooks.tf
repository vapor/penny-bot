resource "aws_lambda_function" "gh_hooks" {
  function_name = local.lambda_function_names.gh_hooks
  s3_bucket     = aws_s3_bucket.lambdas_store.id
  s3_key        = "${local.lambda_function_names.gh_hooks}.zip"
  role          = aws_iam_role.lambda.arn
  handler       = "handler"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  memory_size   = 512
  timeout       = 30

  environment {
    variables = {
      API_BASE_URL             = local.api_base_url
      BOT_TOKEN_ARN            = aws_secretsmanager_secret.discord_bot_token.arn
      WH_SECRET_ARN            = aws_secretsmanager_secret.github_webhook_secret.arn
      GH_APP_AUTH_PRIV_KEY_ARN = aws_secretsmanager_secret.github_app_private_key.arn
      LOG_LEVEL                = "debug"
    }
  }

  lifecycle {
    ignore_changes = [s3_bucket, s3_key]
  }
}

resource "aws_cloudwatch_log_group" "gh_hooks" {
  name              = "/aws/lambda/${local.lambda_function_names.gh_hooks}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "gh_hooks" {
  statement_id  = "penny-discord-bot-stack-lambdaGHHooksRoutePermission-10BVK7ATQ6UEX"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gh_hooks.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_integration" "gh_hooks" {
  api_id                 = aws_apigatewayv2_api.penny.id
  description            = "Lambda GHHooks Integration"
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  connection_type        = "INTERNET"
  integration_uri        = aws_lambda_function.gh_hooks.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "gh_hooks" {
  api_id    = aws_apigatewayv2_api.penny.id
  route_key = "POST /gh-hooks"
  target    = "integrations/${aws_apigatewayv2_integration.gh_hooks.id}"
}
