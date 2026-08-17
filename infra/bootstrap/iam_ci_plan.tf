data "aws_iam_policy_document" "ci_plan_assume" {
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
      values   = ["repo:vapor/penny-bot:pull_request"]
    }
  }
}

resource "aws_iam_role" "ci_plan" {
  name               = module.constants.role_names.ci_plan
  description        = "Read-only role for planning infra/ on pull requests"
  assume_role_policy = data.aws_iam_policy_document.ci_plan_assume.json
}

data "aws_iam_policy_document" "ci_plan" {
  statement {
    sid       = "TerraformState"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${module.constants.state_bucket}"]
  }

  statement {
    sid       = "TerraformStateObjects"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${module.constants.state_bucket}/*"]
  }

  statement {
    sid = "EcrRead"
    actions = [
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:ListTagsForResource",
      "ecr:GetRepositoryPolicy",
      "ecr:GetLifecyclePolicy",
    ]
    resources = [module.constants.ecr_repository_arn]
  }

  statement {
    sid       = "EcsTaskDefinitionRead"
    actions   = ["ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid = "EcsRead"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:ListTagsForResource",
    ]
    resources = [
      module.constants.ecs_cluster_arn,
      module.constants.ecs_service_arn,
    ]
  }

  statement {
    sid = "LambdaRead"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
      "lambda:ListTags",
    ]
    resources = values(module.constants.lambda_arns)
  }

  statement {
    sid     = "ApiGatewayRead"
    actions = ["apigateway:GET"]
    resources = [
      "arn:aws:apigateway:${local.region}::/apis/${module.constants.api_id}",
      "arn:aws:apigateway:${local.region}::/apis/${module.constants.api_id}/*",
      "arn:aws:apigateway:${local.region}::/tags/*",
    ]
  }

  statement {
    sid = "DynamoDBRead"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource",
    ]
    resources = [
      module.constants.table_arns.penny_user,
      module.constants.table_arns.penny_coin,
      module.constants.table_arns.ghhooks_message_lookup,
    ]
  }

  statement {
    sid = "S3BucketsRead"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketOwnershipControls",
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
      module.constants.bucket_arns.lambdas_store,
      module.constants.bucket_arns.penny_caches,
      module.constants.bucket_arns.auto_pings_lambda,
      module.constants.bucket_arns.faqs_lambda,
      module.constants.bucket_arns.auto_faqs_lambda,
    ]
  }

  statement {
    sid = "SecretsManagerRead"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${module.constants.secret_name_prefix}/*"]
  }

  statement {
    sid     = "LogsRead"
    actions = ["logs:ListTagsForResource"]
    resources = concat(
      local.penny_log_group_arns,
      [for arn in local.penny_log_group_arns : trimsuffix(arn, ":*")]
    )
  }

  statement {
    sid       = "LogsDescribe"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
  }

  statement {
    sid = "Ec2Read"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "IamRead"
    actions = ["iam:GetRole", "iam:ListRoleTags"]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn,
      aws_iam_role.lambda.arn,
    ]
  }
}

resource "aws_iam_role_policy" "ci_plan" {
  name   = "penny-bot-ci-plan"
  role   = aws_iam_role.ci_plan.id
  policy = data.aws_iam_policy_document.ci_plan.json
}
