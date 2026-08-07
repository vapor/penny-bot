module "lambda_auto_faqs" {
  source = "./modules/lambda"

  function_name = local.lambda_function_names.auto_faqs
  role_arn      = data.aws_iam_role.lambda.arn
  s3_bucket     = module.lambdas_store.id
}
