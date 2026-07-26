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

resource "aws_ecr_lifecycle_policy" "penny_bot_discord_image" {
  repository = aws_ecr_repository.penny_bot_discord_image.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the 30 most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
