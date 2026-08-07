data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

module "constants" {
  source = "../modules/constants"

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  secret_arns = module.constants.secret_arns

  invokable_lambda_arns = [
    module.constants.lambda_arns.users,
    module.constants.lambda_arns.auto_pings,
    module.constants.lambda_arns.faqs,
    module.constants.lambda_arns.auto_faqs,
  ]
}
