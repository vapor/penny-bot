data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "bootstrap_config" {
  source = "../modules/bootstrap_config"

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}
