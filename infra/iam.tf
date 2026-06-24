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
  name               = "ecsTaskExecutionRole"
  description        = "Allows ECS tasks to call AWS services on your behalf."
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "ecs_task_execution_secrets_manager_read" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:*"]
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
  name               = "ecsTaskIAMRole"
  description        = "Allows ECS tasks to call AWS services on your behalf."
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "ecs_task_database_migration_perms" {
  statement {
    sid    = "VisualEditor0"
    effect = "Deny"
    actions = [
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:BatchGetItem",
      "dynamodb:PutItem",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
      "dynamodb:CreateTable",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:ConditionCheckItem",
      "dynamodb:Query",
    ]
    resources = [
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-bot-table",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-bot-table/*",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-coin-table",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-coin-table/*",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-user-table",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-user-table/*",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/ghHooks-message-lookup-table",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/ghHooks-message-lookup-table/*",
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_database_migration_perms" {
  name   = "database-migration-perms"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_database_migration_perms.json
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
    resources = ["arn:aws:s3:::penny-caches/*"]
  }
}

resource "aws_iam_role_policy" "ecs_task_s3_caches" {
  name   = "S3-peeny-caches"
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
  name               = "penny-discord-bot-stack-lambdaIAMRole-148Q8DRX26QFA"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "lambda" {
  name = "lambda"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DeleteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:Scan",
          "lambda:UpdateFunctionCode",
          "lambda:InvokeFunction",
          "secretsmanager:GetSecretValue",
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/ghHooks-message-lookup-table",
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-user-table",
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-coin-table",
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-user-table",
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-user-table/*",
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-coin-table",
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-coin-table/*",
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/ghHooks-message-lookup-table",
          "arn:aws:dynamodb:${local.region}:${local.account_id}:table/ghHooks-message-lookup-table/*",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.users}:*",
          "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.users}",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.auto_pings}:*",
          "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.auto_pings}",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.faqs}:*",
          "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.faqs}",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.auto_faqs}:*",
          "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.auto_faqs}",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.gh_hooks}:*",
          "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.gh_hooks}",
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.gh_oauth}:*",
          "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.gh_oauth}",
          aws_secretsmanager_secret.discord_bot_token.arn,
          aws_secretsmanager_secret.github_webhook_secret.arn,
          aws_secretsmanager_secret.github_app_client_secret.arn,
          aws_secretsmanager_secret.github_app_private_key.arn,
          "arn:aws:s3:::penny-auto-pings-lambda/*",
          "arn:aws:s3:::penny-faqs-lambda/*",
          "arn:aws:s3:::penny-auto-faqs-lambda/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user" "deployer" {
  name = "penny-bot-deployer"
}

resource "aws_iam_access_key" "deployer" {
  user = aws_iam_user.deployer.name
}

data "aws_iam_policy_document" "penny_bot_ecr" {
  statement {
    sid    = "VisualEditor0"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetAuthorizationToken",
      "ecr:UploadLayerPart",
      "ec2:DescribeSubnets",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:RegisterTaskDefinition",
      "iam:PassRole",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "penny_bot_ecr" {
  name   = "PennyBotECR"
  policy = data.aws_iam_policy_document.penny_bot_ecr.json
}

data "aws_iam_policy_document" "penny_bot_deployer" {
  statement {
    sid    = "VisualEditor0"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:UpdateFunctionConfiguration",
      "lambda:DeleteFunction",
      "lambda:InvokeFunction",
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "s3:CreateBucket",
      "s3:GetObjectAcl",
      "s3:PutBucketAcl",
      "s3:DeleteObject",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
      "s3:GetObject",
      "s3:PutObjectVersionAcl",
      "s3:DeleteObjectVersion",
      "s3:ListBucketVersions",
      "s3:ListBucket",
      "s3:GetBucketPolicy",
      "s3:AbortMultipartUpload",
      "s3:PutObjectAcl",
      "s3:ListBucketMultipartUploads",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetObjectVersion",
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:GetRole",
      "iam:CreateServiceLinkedRole",
      "iam:DeleteRole",
      "iam:PassRole",
      "iam:DeleteRolePolicy",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:BatchGetItem",
      "dynamodb:PutItem",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
      "dynamodb:CreateTable",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:ConditionCheckItem",
      "dynamodb:Query",
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:DELETE",
      "apigateway:PATCH",
      "apigateway:PUT",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy",
    ]
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/ecs/${local.api_name}:*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.users}:*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.auto_pings}:*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.faqs}:*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.auto_faqs}:*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/SponsorsLambda:*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.gh_hooks}:*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.lambda_function_names.gh_oauth}:*",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-bot-table",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-bot-table/*",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-coin-table",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-coin-table/*",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-user-table",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/penny-user-table/*",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/ghHooks-message-lookup-table",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/ghHooks-message-lookup-table/*",
      "arn:aws:apigateway:${local.region}::/apis",
      "arn:aws:apigateway:${local.region}::/apis/*",
      "arn:aws:iam::${local.account_id}:role/service-role/PennyBotAppRunner",
      "arn:aws:iam::${local.account_id}:role/penny-discord-bot-stack*",
      "arn:aws:s3:::penny-lambdas-store",
      "arn:aws:s3:::penny-auto-pings-lambda",
      "arn:aws:s3:::penny-faqs-lambda",
      "arn:aws:s3:::penny-auto-faqs-lambda",
      "arn:aws:s3:::penny-caches",
      "arn:aws:s3:::penny-lambdas-store/*",
      "arn:aws:s3:::penny-auto-pings-lambda/*",
      "arn:aws:s3:::penny-faqs-lambda/*",
      "arn:aws:s3:::penny-auto-faqs-lambda/*",
      "arn:aws:s3:::penny-caches/*",
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.faqs}",
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.auto_faqs}",
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.auto_pings}",
      "arn:aws:lambda:${local.region}:${local.account_id}:function:SponsorsLambda",
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.users}",
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.gh_hooks}",
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_names.gh_oauth}",
    ]
  }

  statement {
    sid    = "VisualEditor1"
    effect = "Allow"
    actions = [
      "apigateway:DELETE",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:POST",
      "apigateway:GET",
    ]
    resources = [
      "arn:aws:apigateway:${local.region}::/apis",
      "arn:aws:apigateway:${local.region}::/apis/*",
      "arn:aws:apigateway:${local.region}::/tags/*",
    ]
  }

  statement {
    sid    = "VisualEditor6"
    effect = "Allow"
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:CreateChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:DescribeEvents",
      "cloudformation:DescribeStackEvents",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeStacks",
    ]
    resources = [
      "arn:aws:cloudformation:${local.region}:${local.account_id}:stack/penny-discord-bot-stack/*",
      "arn:aws:s3:::penny-lambdas-store/*",
      "arn:aws:s3:::penny-lambdas-store",
      "arn:aws:apigateway:${local.region}::/apis",
      "arn:aws:apigateway:${local.region}::/apis/*",
      "arn:aws:apigateway:${local.region}::/tags/*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/PennyLambda:*",
      "arn:aws:apprunner:${local.region}:${local.account_id}:service/Penny-Bot/*",
      "arn:aws:iam::${local.account_id}:role/service-role/PennyBotAppRunner",
      "arn:aws:iam::${local.account_id}:role/penny-discord-bot-stack*",
    ]
  }

  statement {
    sid    = "VisualEditor7"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "penny_bot_deployer" {
  name        = "penny-bot-deployer-policy"
  description = "Provides access to the resources needed to deploy the Penny Discord Bot"
  policy      = data.aws_iam_policy_document.penny_bot_deployer.json
}

resource "aws_iam_user_policy_attachment" "deployer_penny_bot_ecr" {
  user       = aws_iam_user.deployer.name
  policy_arn = aws_iam_policy.penny_bot_ecr.arn
}

resource "aws_iam_user_policy_attachment" "deployer_penny_bot_deployer" {
  user       = aws_iam_user.deployer.name
  policy_arn = aws_iam_policy.penny_bot_deployer.arn
}

resource "aws_iam_user_policy_attachment" "deployer_app_runner" {
  user       = aws_iam_user.deployer.name
  policy_arn = "arn:aws:iam::aws:policy/AWSAppRunnerFullAccess"
}

data "aws_iam_policy_document" "apprunner_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apprunner" {
  name               = "PennyBotAppRunner"
  path               = "/service-role/"
  description        = "This role gives App Runner permission to access ECR"
  assume_role_policy = data.aws_iam_policy_document.apprunner_assume.json
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr" {
  role       = aws_iam_role.apprunner.name
  policy_arn = aws_iam_policy.penny_bot_ecr.arn
}
