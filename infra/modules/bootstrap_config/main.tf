locals {
  api_name     = "penny-bot-api"
  api_id       = "ncy6caaavg"
  state_bucket = "penny-bot-terraform-state"

  ecs_cluster_name    = "${local.api_name}-Cluster"
  ecs_service_name    = "Penny-Bot"
  ecr_repository_name = "penny-bot-discord-image"

  secret_name_prefix = "prod/penny/penny-bot"

  lambda_function_names = {
    users      = "UsersLambda"
    auto_pings = "AutoPingsLambda"
    faqs       = "FaqsLambda"
    auto_faqs  = "AutoFaqsLambda"
    gh_hooks   = "GHHooksLambda"
    gh_oauth   = "GHOAuthLambda"
  }

  role_names = {
    ecs_task_execution = "ecsTaskExecutionRole"
    ecs_task           = "ecsTaskIAMRole"
    lambda             = "penny-discord-bot-stack-lambdaIAMRole-148Q8DRX26QFA"
    github_deploy      = "penny-bot-deploy"
  }

  secret_names = {
    discord_bot_token        = "${local.secret_name_prefix}/discord-bot-token"
    logs_webhook_url         = "${local.secret_name_prefix}/logs-webhook-url"
    github_webhook_secret    = "${local.secret_name_prefix}/github-webhook-secret"
    github_app_client_secret = "${local.secret_name_prefix}/github-penny-app-client-secret"
    github_app_private_key   = "${local.secret_name_prefix}/github-penny-app-private-key"
    account_linking_priv_key = "${local.secret_name_prefix}/account-linking-oauth-flow-priv-key"
    stack_overflow_api_key   = "${local.secret_name_prefix}/stack-overflow-api-key"
  }

  table_names = {
    penny_user             = "penny-user-table"
    penny_coin             = "penny-coin-table"
    ghhooks_message_lookup = "ghHooks-message-lookup-table"
  }

  bucket_names = {
    lambdas_store     = "penny-lambdas-store"
    penny_caches      = "penny-caches"
    auto_pings_lambda = "penny-auto-pings-lambda"
    faqs_lambda       = "penny-faqs-lambda"
    auto_faqs_lambda  = "penny-auto-faqs-lambda"
  }

  log_group_names = merge(
    {
      ecs_api    = "/ecs/${local.api_name}"
      api_access = "/aws/apigateway/${local.api_name}"
    },
    { for key, name in local.lambda_function_names : key => "/aws/lambda/${name}" }
  )

  lambda_arns = {
    for key, name in local.lambda_function_names :
    key => "arn:aws:lambda:${var.region}:${var.account_id}:function:${name}"
  }

  table_arns = {
    for key, name in local.table_names :
    key => "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${name}"
  }

  bucket_arns = {
    for key, name in local.bucket_names :
    key => "arn:aws:s3:::${name}"
  }

  log_group_arns = {
    for key, name in local.log_group_names :
    key => "arn:aws:logs:${var.region}:${var.account_id}:log-group:${name}"
  }
}
