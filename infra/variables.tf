variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "aws_profile" {
  type    = string
  default = "vapor"
}

variable "ecs_subnet_id" {
  type    = string
  default = "subnet-088d7192c6c67e077"
}

variable "github_oidc_role_name" {
  type    = string
  default = "GithubOIdP-Role-zJ3kkJbhrNkr"
}

variable "penny_image_tag" {
  type    = string
  default = null
}
