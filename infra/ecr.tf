resource "aws_ecr_repository" "penny_bot_discord_image" {
  name                 = module.constants.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

data "aws_ecr_lifecycle_policy_document" "penny_bot_discord_image" {
  rule {
    priority    = 1
    description = "Keep only the 30 most recent images"

    selection {
      tag_status   = "any"
      count_type   = "imageCountMoreThan"
      count_number = 30
    }

    action {
      type = "expire"
    }
  }
}

resource "aws_ecr_lifecycle_policy" "penny_bot_discord_image" {
  repository = aws_ecr_repository.penny_bot_discord_image.name

  policy = data.aws_ecr_lifecycle_policy_document.penny_bot_discord_image.json
}
