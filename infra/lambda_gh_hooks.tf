module "lambda_gh_hooks" {
  source = "./modules/lambda"

  function_name           = local.lambda_function_names.gh_hooks
  role_arn                = data.aws_iam_role.lambda.arn
  s3_bucket               = module.lambdas_store.id
  memory_size             = 512
  timeout                 = 30
  api_id                  = aws_apigatewayv2_api.penny.id
  api_execution_arn       = aws_apigatewayv2_api.penny.execution_arn
  integration_description = "Lambda GHHooks Integration"
  routes                  = ["POST /gh-hooks"]

  environment = {
    API_BASE_URL             = local.api_base_url
    BOT_TOKEN_ARN            = aws_secretsmanager_secret.discord_bot_token.arn
    WH_SECRET_ARN            = aws_secretsmanager_secret.github_webhook_secret.arn
    GH_APP_AUTH_PRIV_KEY_ARN = aws_secretsmanager_secret.github_app_private_key.arn
    LOG_LEVEL                = "debug"
  }
}
