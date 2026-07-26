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
