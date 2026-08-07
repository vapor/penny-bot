module "lambda_users" {
  source = "./modules/lambda"

  function_name = local.lambda_function_names.users
  role_arn      = data.aws_iam_role.lambda.arn
  s3_bucket     = module.lambdas_store.id

  environment = {
    LOG_LEVEL = "debug"
  }
}
