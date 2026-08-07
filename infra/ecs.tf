resource "aws_ecs_cluster" "penny" {
  name = module.constants.ecs_cluster_name
}

resource "aws_ecs_task_definition" "penny" {
  family                   = "penny-bot"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = data.aws_iam_role.ecs_task_execution.arn
  task_role_arn            = data.aws_iam_role.ecs_task.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name           = "penny-bot"
      image          = "${aws_ecr_repository.penny_bot_discord_image.repository_url}:${local.penny_image_tag}"
      cpu            = 0
      essential      = true
      portMappings   = []
      mountPoints    = []
      volumesFrom    = []
      systemControls = []
      environment = [
        {
          name  = "DEPLOYMENT_ENVIRONMENT"
          value = "prod"
        },
        {
          name  = "GH_OAUTH_CLIENT_ID"
          value = module.constants.gh_oauth_client_id
        }
      ]
      secrets = [
        {
          name      = "BOT_TOKEN"
          valueFrom = aws_secretsmanager_secret.discord_bot_token.arn
        },
        {
          name      = "LOGGING_WEBHOOK_URL"
          valueFrom = aws_secretsmanager_secret.logs_webhook_url.arn
        },
        {
          name      = "ACCOUNT_LINKING_OAUTH_FLOW_PRIV_KEY"
          valueFrom = aws_secretsmanager_secret.account_linking_priv_key.arn
        },
        {
          name      = "SO_API_KEY"
          valueFrom = aws_secretsmanager_secret.stack_overflow_api_key.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_api.name
          awslogs-region        = local.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "penny" {
  name                  = module.constants.ecs_service_name
  cluster               = aws_ecs_cluster.penny.id
  task_definition       = "${aws_ecs_task_definition.penny.family}:${aws_ecs_task_definition.penny.revision}"
  desired_count         = 1
  launch_type           = "FARGATE"
  platform_version      = "1.4.0"
  wait_for_steady_state = true

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }
}
