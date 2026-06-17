resource "aws_cloudwatch_log_group" "ecs_api" {
  name              = "/ecs/${local.api_name}"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "api_access_logs" {
  name              = "/aws/lambda/PennyLambda"
  retention_in_days = 30
}
