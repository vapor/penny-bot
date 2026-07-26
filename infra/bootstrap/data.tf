data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

module "bootstrap_config" {
  source = "../modules/bootstrap_config"

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

data "aws_secretsmanager_secret" "this" {
  for_each = module.bootstrap_config.secret_names

  name = each.value
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  secret_arns = { for key, secret in data.aws_secretsmanager_secret.this : key => secret.arn }
}
