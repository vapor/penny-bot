terraform {
  required_version = "1.15.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.50.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # A hack to skip using a profile in CI, to use OIDC instead
  profile = var.aws_profile == "" ? null : var.aws_profile
}
