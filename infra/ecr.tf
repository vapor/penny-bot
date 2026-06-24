resource "aws_ecr_repository" "penny_bot_discord_image" {
  name                 = "penny-bot-discord-image"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

data "aws_iam_policy_document" "ecr_penny_bot_discord_image" {
  statement {
    sid    = "penny-discord-ecs role"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["AROASSTYTBM4BRFJQDX6P"]
    }

    actions = [
      "ecr:ListImages",
      "ecr:PutImage",
    ]
  }
}

resource "aws_ecr_repository_policy" "penny_bot_discord_image" {
  repository = aws_ecr_repository.penny_bot_discord_image.name
  policy     = data.aws_iam_policy_document.ecr_penny_bot_discord_image.json
}
