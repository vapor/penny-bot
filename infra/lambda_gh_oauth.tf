module "lambda_gh_oauth" {
  source = "./modules/lambda_endpoint"

  function_name           = local.lambda_function_names.gh_oauth
  role_arn                = data.aws_iam_role.lambda.arn
  s3_bucket               = module.lambdas_store.id
  api_id                  = aws_apigatewayv2_api.penny.id
  api_execution_arn       = aws_apigatewayv2_api.penny.execution_arn
  integration_description = "Lambda GHOAuth Integration"
  routes                  = ["GET /gh-oauth"]

  environment = {
    API_BASE_URL                       = local.api_base_url
    BOT_TOKEN_ARN                      = aws_secretsmanager_secret.discord_bot_token.arn
    ACCOUNT_LINKING_OAUTH_FLOW_PUB_KEY = "LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUZrd0V3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFZlR5bkhvSnEwNHhOaVN1cmRGK0JpcXVyRDh1NQp1RjdGU2V4OGFNalhXTVpreFgrZ0d3U3lwazBIMExvQ2g0LzFKK1Vhbkp4MzhWVDIwMVJpa2RVZ25BPT0KLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0tCg=="
    GH_CLIENT_ID                       = "Iv1.683ea075648a5cd2"
    LOG_LEVEL                          = "trace"
    GH_CLIENT_SECRET_ARN               = aws_secretsmanager_secret.github_app_client_secret.arn
  }
}
