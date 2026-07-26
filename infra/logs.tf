resource "aws_cloudwatch_log_group" "ecs_api" {
  name              = module.constants.log_group_names.ecs_api
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "api_access_logs" {
  name              = module.constants.log_group_names.api_access
  retention_in_days = 30
}
