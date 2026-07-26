output "api_name" {
  value = local.api_name
}

output "api_id" {
  value = local.api_id
}

output "state_bucket" {
  value = local.state_bucket
}

output "ecs_cluster_name" {
  value = local.ecs_cluster_name
}

output "ecs_service_name" {
  value = local.ecs_service_name
}

output "ecr_repository_name" {
  value = local.ecr_repository_name
}

output "secret_name_prefix" {
  value = local.secret_name_prefix
}

output "lambda_function_names" {
  value = local.lambda_function_names
}

output "role_names" {
  value = local.role_names
}

output "secret_names" {
  value = local.secret_names
}

output "table_names" {
  value = local.table_names
}

output "bucket_names" {
  value = local.bucket_names
}

output "log_group_names" {
  value = local.log_group_names
}

output "lambda_arns" {
  value = local.lambda_arns
}

output "table_arns" {
  value = local.table_arns
}

output "bucket_arns" {
  value = local.bucket_arns
}

output "log_group_arns" {
  value = local.log_group_arns
}

output "ecs_cluster_arn" {
  value = "arn:aws:ecs:${var.region}:${var.account_id}:cluster/${local.ecs_cluster_name}"
}

output "ecs_service_arn" {
  value = "arn:aws:ecs:${var.region}:${var.account_id}:service/${local.ecs_cluster_name}/${local.ecs_service_name}"
}

output "ecr_repository_arn" {
  value = "arn:aws:ecr:${var.region}:${var.account_id}:repository/${local.ecr_repository_name}"
}

output "state_bucket_arn" {
  value = "arn:aws:s3:::${local.state_bucket}"
}

output "secret_arn_prefix" {
  value = "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${local.secret_name_prefix}"
}
