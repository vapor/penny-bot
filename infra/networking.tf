resource "aws_security_group" "ecs_service" {
  name        = "${local.api_name}-ecs"
  description = "penny-bot-api-SecurityGroup"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
