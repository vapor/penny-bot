resource "aws_secretsmanager_secret" "discord_bot_token" {
  name = module.constants.secret_names.discord_bot_token

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "logs_webhook_url" {
  name = module.constants.secret_names.logs_webhook_url

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "github_webhook_secret" {
  name        = module.constants.secret_names.github_webhook_secret
  description = "Secret for GitHub webhook used to send various events to Penny"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "github_app_client_secret" {
  name        = module.constants.secret_names.github_app_client_secret
  description = "Client secret for the full GH app"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "github_app_private_key" {
  name        = module.constants.secret_names.github_app_private_key
  description = "Private key for the GH app to sign access token requests"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "account_linking_priv_key" {
  name        = module.constants.secret_names.account_linking_priv_key
  description = "The private key used to sign JWT tokens used in process of linking GitHub accounts to Discord accounts."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "stack_overflow_api_key" {
  name = module.constants.secret_names.stack_overflow_api_key

  lifecycle {
    prevent_destroy = true
  }
}
