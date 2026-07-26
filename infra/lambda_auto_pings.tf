module "lambda_auto_pings" {
  source = "./modules/lambda_endpoint"

  function_name           = local.lambda_function_names.auto_pings
  role_arn                = aws_iam_role.lambda.arn
  s3_bucket               = module.lambdas_store.id
  api_id                  = aws_apigatewayv2_api.penny.id
  api_execution_arn       = aws_apigatewayv2_api.penny.execution_arn
  integration_description = "Lambda Auto-Pings Integration"

  routes = [
    "GET /auto-pings/all",
    "PUT /auto-pings/users",
    "DELETE /auto-pings/users",
  ]
}
