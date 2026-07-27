terraform {
  backend "s3" {
    bucket       = "penny-bot-terraform-state"
    key          = "penny-bot/bootstrap.tfstate"
    region       = "eu-west-1"
    profile      = "vapor"
    encrypt      = true
    use_lockfile = true
  }
}
