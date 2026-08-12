terraform {
  required_version = "1.15.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.58.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # A hack to skip using a profile in CI, to use OIDC instead
  profile = var.aws_profile == "" ? null : var.aws_profile

  default_tags {
    tags = {
      Project   = "penny-bot"
      ManagedBy = "terraform"
    }
  }
}
