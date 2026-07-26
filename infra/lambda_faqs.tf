module "lambda_faqs" {
  source = "./modules/lambda_endpoint"

  function_name           = local.lambda_function_names.faqs
  role_arn                = aws_iam_role.lambda.arn
  s3_bucket               = module.lambdas_store.id
  api_id                  = aws_apigatewayv2_api.penny.id
  api_execution_arn       = aws_apigatewayv2_api.penny.execution_arn
  integration_description = "Lambda Faqs Integration"
  routes                  = ["POST /faqs"]
}
