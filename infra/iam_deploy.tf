data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  state_bucket = "penny-bot-terraform-state"

  penny_log_group_arns = [
    for lg in concat(
      ["/ecs/${local.api_name}", "/aws/lambda/PennyLambda"],
      [for n in values(local.lambda_function_names) : "/aws/lambda/${n}"]
    ) : "arn:aws:logs:${local.region}:${local.account_id}:log-group:${lg}:*"
  ]

  penny_lambda_arns = [
    aws_lambda_function.users.arn,
    aws_lambda_function.auto_pings.arn,
    aws_lambda_function.faqs.arn,
    aws_lambda_function.auto_faqs.arn,
    aws_lambda_function.gh_hooks.arn,
    aws_lambda_function.gh_oauth.arn,
  ]
}

data "aws_iam_policy_document" "github_deploy_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:vapor/penny-bot:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "penny-bot-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_deploy_assume.json
}

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "TerraformState"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${local.state_bucket}"]
  }

  statement {
    sid       = "TerraformStateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/*"]
  }

  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrRepo"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:DescribeRepositories",
      "ecr:ListTagsForResource",
      "ecr:GetRepositoryPolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:GetLifecyclePolicy",
    ]
    resources = [aws_ecr_repository.penny_bot_discord_image.arn]
  }

  statement {
    sid = "EcsTaskDefinition"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid = "EcsServiceAndCluster"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:ListTagsForResource",
    ]
    resources = [
      aws_ecs_cluster.penny.arn,
      aws_ecs_service.penny.id,
    ]
  }

  statement {
    sid = "Lambda"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
      "lambda:UpdateFunctionConfiguration",
      "lambda:UpdateFunctionCode",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:ListTags",
      "lambda:TagResource",
      "lambda:UntagResource",
    ]
    resources = local.penny_lambda_arns
  }

  statement {
    sid = "ApiGateway"
    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE",
    ]
    resources = [
      "arn:aws:apigateway:${local.region}::/apis",
      "arn:aws:apigateway:${local.region}::/apis/*",
      "arn:aws:apigateway:${local.region}::/tags/*",
    ]
  }

  statement {
    sid = "DynamoDB"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource",
      "dynamodb:UpdateTable",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:TagResource",
    ]
    resources = [
      aws_dynamodb_table.penny_user.arn,
      aws_dynamodb_table.penny_coin.arn,
      aws_dynamodb_table.ghhooks_message_lookup.arn,
    ]
  }

  statement {
    sid = "S3Buckets"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:PutBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketOwnershipControls",
      "s3:PutBucketOwnershipControls",
      "s3:GetBucketTagging",
      "s3:GetBucketPolicy",
      "s3:GetBucketAcl",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketLogging",
      "s3:GetBucketWebsite",
      "s3:GetBucketCORS",
      "s3:GetReplicationConfiguration",
      "s3:GetBucketObjectLockConfiguration",
    ]
    resources = [
      aws_s3_bucket.lambdas_store.arn,
      aws_s3_bucket.penny_caches.arn,
      aws_s3_bucket.auto_pings_lambda.arn,
      aws_s3_bucket.faqs_lambda.arn,
      aws_s3_bucket.auto_faqs_lambda.arn,
    ]
  }

  statement {
    sid = "SecretsManager"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:UpdateSecret",
      "secretsmanager:TagResource",
    ]
    resources = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:prod/penny/penny-bot/*"]
  }

  statement {
    sid = "Logs"
    actions = [
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagResource",
    ]
    resources = local.penny_log_group_arns
  }

  statement {
    sid = "IamRead"
    actions = [
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRoleTags",
      "iam:GetUser",
      "iam:ListAttachedUserPolicies",
      "iam:ListUserPolicies",
      "iam:ListUserTags",
      "iam:ListAccessKeys",
      "iam:GetAccessKeyLastUsed",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:GetOpenIDConnectProvider",
    ]
    resources = ["*"]
  }

  statement {
    sid = "IamManage"
    actions = [
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:AttachUserPolicy",
      "iam:DetachUserPolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn,
      aws_iam_role.lambda.arn,
      aws_iam_role.github_deploy.arn,
      aws_iam_user.deployer.arn,
      aws_iam_policy.penny_bot_ecr.arn,
      aws_iam_policy.penny_bot_deployer.arn,
    ]
  }

  statement {
    sid     = "IamPassRole"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn,
      aws_iam_role.lambda.arn,
    ]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "penny-bot-terraform-deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}
