output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "ci_deploy_role_arn" {
  value = aws_iam_role.ci_deploy.arn
}

output "ci_plan_role_arn" {
  value = aws_iam_role.ci_plan.arn
}
