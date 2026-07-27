output "api_base_url" {
  value = local.api_base_url
}

output "api_id" {
  value = aws_apigatewayv2_api.penny.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.penny_bot_discord_image.repository_url
}
