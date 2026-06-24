output "api_base_url" {
  value = local.api_base_url
}

output "api_id" {
  value = aws_apigatewayv2_api.penny.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.penny_bot_discord_image.repository_url
}

output "users_lambda_arn" {
  value = aws_lambda_function.users.arn
}

output "auto_pings_lambda_arn" {
  value = aws_lambda_function.auto_pings.arn
}

output "faqs_lambda_arn" {
  value = aws_lambda_function.faqs.arn
}

output "auto_faqs_lambda_arn" {
  value = aws_lambda_function.auto_faqs.arn
}

output "gh_hooks_lambda_arn" {
  value = aws_lambda_function.gh_hooks.arn
}

output "gh_oauth_lambda_arn" {
  value = aws_lambda_function.gh_oauth.arn
}

output "penny_user_table_arn" {
  value = aws_dynamodb_table.penny_user.arn
}

output "penny_coin_table_arn" {
  value = aws_dynamodb_table.penny_coin.arn
}

output "ghhooks_message_lookup_table_arn" {
  value = aws_dynamodb_table.ghhooks_message_lookup.arn
}

output "github_oidc_role_arn" {
  value = data.aws_iam_role.github_oidc.arn
}

