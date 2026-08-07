module "lambda_auto_pings" {
  source = "./modules/lambda"

  function_name = local.lambda_function_names.auto_pings
  role_arn      = data.aws_iam_role.lambda.arn
  s3_bucket     = module.lambdas_store.id
}
