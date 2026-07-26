data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = module.constants.role_names.ecs_task_execution
  description        = "Allows ECS tasks to call AWS services on your behalf."
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "ecs_task_execution_secrets_manager_read" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      local.secret_arns.discord_bot_token,
      local.secret_arns.logs_webhook_url,
      local.secret_arns.account_linking_priv_key,
      local.secret_arns.stack_overflow_api_key,
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets_manager_read" {
  name   = "secrets-manager-read"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets_manager_read.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = module.constants.role_names.ecs_task
  description        = "Allows ECS tasks to call AWS services on your behalf."
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "ecs_task_s3_caches" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = ["${module.constants.bucket_arns.penny_caches}/*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_s3_caches" {
  name   = "S3-penny-caches"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_s3_caches.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = module.constants.role_names.lambda
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "lambda" {
  name   = "lambda"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      for name in values(module.constants.lambda_function_names) :
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${name}:*"
    ]
  }

  statement {
    sid    = "DynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = flatten([
      for arn in [
        module.constants.table_arns.penny_user,
        module.constants.table_arns.penny_coin,
        module.constants.table_arns.ghhooks_message_lookup,
      ] : [arn, "${arn}/*"]
    ])
  }

  statement {
    sid     = "SecretsManager"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      local.secret_arns.discord_bot_token,
      local.secret_arns.github_webhook_secret,
      local.secret_arns.github_app_client_secret,
      local.secret_arns.github_app_private_key,
    ]
  }

  statement {
    sid     = "S3"
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetObject"]
    resources = [
      "${module.constants.bucket_arns.auto_pings_lambda}/*",
      "${module.constants.bucket_arns.faqs_lambda}/*",
      "${module.constants.bucket_arns.auto_faqs_lambda}/*",
    ]
  }
}
