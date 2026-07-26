data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_iam_role" "github_oidc" {
  name = var.github_oidc_role_name
}

data "aws_ecs_container_definition" "current" {
  count           = var.penny_image_tag == null ? 1 : 0
  task_definition = "penny-bot"
  container_name  = "penny-bot"
}

module "bootstrap_config" {
  source = "./modules/bootstrap_config"

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  api_name = module.bootstrap_config.api_name

  lambda_function_names = module.bootstrap_config.lambda_function_names

  api_base_url = "https://${aws_apigatewayv2_api.penny.id}.execute-api.${local.region}.amazonaws.com/prod"

  penny_image_tag = var.penny_image_tag != null ? var.penny_image_tag : reverse(split(":", data.aws_ecs_container_definition.current[0].image))[0]
}
