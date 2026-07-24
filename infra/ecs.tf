resource "aws_ecs_cluster" "penny" {
  name = "${local.api_name}-Cluster"
}

resource "aws_ecs_task_definition" "penny" {
  family                   = "penny-bot"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

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
          name  = "API_BASE_URL"
          value = local.api_base_url
        },
        {
          name  = "DEPLOYMENT_ENVIRONMENT"
          value = "prod"
        },
        {
          name  = "GH_OAUTH_CLIENT_ID"
          value = "Iv1.683ea075648a5cd2"
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
          awslogs-group         = "/ecs/${local.api_name}"
          awslogs-region        = local.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "penny" {
  name                  = "Penny-Bot"
  cluster               = aws_ecs_cluster.penny.id
  task_definition       = "${aws_ecs_task_definition.penny.family}:${aws_ecs_task_definition.penny.revision}"
  desired_count         = 1
  launch_type           = "FARGATE"
  platform_version      = "1.4.0"
  wait_for_steady_state = true

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = [var.ecs_subnet_id]
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }
}

resource "aws_s3_bucket" "penny_caches" {
  bucket = "penny-caches"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "penny_caches" {
  bucket = aws_s3_bucket.penny_caches.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_public_access_block" "penny_caches" {
  bucket                  = aws_s3_bucket.penny_caches.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "penny_caches" {
  bucket = aws_s3_bucket.penny_caches.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

