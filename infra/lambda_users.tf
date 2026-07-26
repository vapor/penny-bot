module "lambda_users" {
  source = "./modules/lambda_endpoint"

  function_name           = local.lambda_function_names.users
  role_arn                = aws_iam_role.lambda.arn
  s3_bucket               = module.lambdas_store.id
  api_id                  = aws_apigatewayv2_api.penny.id
  api_execution_arn       = aws_apigatewayv2_api.penny.execution_arn
  integration_description = "Lambda Users Integration"
  routes                  = ["POST /users"]

  environment = {
    API_BASE_URL = local.api_base_url
    LOG_LEVEL    = "debug"
  }
}
