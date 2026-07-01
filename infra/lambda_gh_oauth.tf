resource "aws_lambda_function" "gh_oauth" {
  function_name = local.lambda_function_names.gh_oauth
  s3_bucket     = aws_s3_bucket.lambdas_store.id
  s3_key        = "${local.lambda_function_names.gh_oauth}.zip"
  role          = aws_iam_role.lambda.arn
  handler       = "handler"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  memory_size   = 256
  timeout       = 20

  environment {
    variables = {
      API_BASE_URL                       = local.api_base_url
      BOT_TOKEN_ARN                      = aws_secretsmanager_secret.discord_bot_token.arn
      ACCOUNT_LINKING_OAUTH_FLOW_PUB_KEY = "LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUZrd0V3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFZlR5bkhvSnEwNHhOaVN1cmRGK0JpcXVyRDh1NQp1RjdGU2V4OGFNalhXTVpreFgrZ0d3U3lwazBIMExvQ2g0LzFKK1Vhbkp4MzhWVDIwMVJpa2RVZ25BPT0KLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0tCg=="
      GH_CLIENT_ID                       = "Iv1.683ea075648a5cd2"
      LOG_LEVEL                          = "trace"
      GH_CLIENT_SECRET_ARN               = aws_secretsmanager_secret.github_app_client_secret.arn
    }
  }

  lifecycle {
    ignore_changes = [s3_bucket, s3_key]
  }
}

resource "aws_cloudwatch_log_group" "gh_oauth" {
  name              = "/aws/lambda/${local.lambda_function_names.gh_oauth}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "gh_oauth" {
  statement_id  = "penny-discord-bot-stack-lambdaGHOAuthRoutePermission-1KQ0FJWLA5LI2"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gh_oauth.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_integration" "gh_oauth" {
  api_id                 = aws_apigatewayv2_api.penny.id
  description            = "Lambda GHOAuth Integration"
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  connection_type        = "INTERNET"
  integration_uri        = aws_lambda_function.gh_oauth.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "gh_oauth" {
  api_id    = aws_apigatewayv2_api.penny.id
  route_key = "GET /gh-oauth"
  target    = "integrations/${aws_apigatewayv2_integration.gh_oauth.id}"
}
