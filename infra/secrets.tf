resource "aws_secretsmanager_secret" "discord_bot_token" {
  name = "prod/penny/penny-bot/discord-bot-token"
}

resource "aws_secretsmanager_secret" "trigger_gh_readme_token" {
  name        = "prod/penny/penny-bot/trigger-gh-readme-workflow-token"
  description = "This secret contains a GitHub token that is used to trigger a workflow when a new sponsor joins the vapor org"
}

resource "aws_secretsmanager_secret" "logs_webhook_url" {
  name = "prod/penny/penny-bot/logs-webhook-url"
}

resource "aws_secretsmanager_secret" "github_webhook_secret" {
  name        = "prod/penny/penny-bot/github-webhook-secret"
  description = "Secret for GitHub webhook used to send various events to Penny"
}

resource "aws_secretsmanager_secret" "github_app_client_secret" {
  name        = "prod/penny/penny-bot/github-penny-app-client-secret"
  description = "Client secret for the full GH app"
}

resource "aws_secretsmanager_secret" "github_app_private_key" {
  name        = "prod/penny/penny-bot/github-penny-app-private-key"
  description = "Private key for the GH app to sign access token requests "
}

resource "aws_secretsmanager_secret" "account_linking_priv_key" {
  name        = "prod/penny/penny-bot/account-linking-oauth-flow-priv-key"
  description = "The private key used to sign JWT tokens used in process of linking GitHub accounts to Discord accounts."
}

resource "aws_secretsmanager_secret" "stack_overflow_api_key" {
  name = "prod/penny/penny-bot/stack-overflow-api-key"
}
