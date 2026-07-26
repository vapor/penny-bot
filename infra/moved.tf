moved {
  from = aws_s3_bucket.lambdas_store
  to   = module.lambdas_store.aws_s3_bucket.this
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.lambdas_store
  to   = module.lambdas_store.aws_s3_bucket_server_side_encryption_configuration.this
}

moved {
  from = aws_s3_bucket_public_access_block.lambdas_store
  to   = module.lambdas_store.aws_s3_bucket_public_access_block.this
}

moved {
  from = aws_s3_bucket_ownership_controls.lambdas_store
  to   = module.lambdas_store.aws_s3_bucket_ownership_controls.this
}

moved {
  from = aws_s3_bucket.penny_caches
  to   = module.penny_caches.aws_s3_bucket.this
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.penny_caches
  to   = module.penny_caches.aws_s3_bucket_server_side_encryption_configuration.this
}

moved {
  from = aws_s3_bucket_public_access_block.penny_caches
  to   = module.penny_caches.aws_s3_bucket_public_access_block.this
}

moved {
  from = aws_s3_bucket_ownership_controls.penny_caches
  to   = module.penny_caches.aws_s3_bucket_ownership_controls.this
}

moved {
  from = aws_s3_bucket.auto_pings_lambda
  to   = module.auto_pings_lambda.aws_s3_bucket.this
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.auto_pings_lambda
  to   = module.auto_pings_lambda.aws_s3_bucket_server_side_encryption_configuration.this
}

moved {
  from = aws_s3_bucket_public_access_block.auto_pings_lambda
  to   = module.auto_pings_lambda.aws_s3_bucket_public_access_block.this
}

moved {
  from = aws_s3_bucket_ownership_controls.auto_pings_lambda
  to   = module.auto_pings_lambda.aws_s3_bucket_ownership_controls.this
}

moved {
  from = aws_s3_bucket_versioning.auto_pings_lambda
  to   = module.auto_pings_lambda.aws_s3_bucket_versioning.this[0]
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.auto_pings_lambda
  to   = module.auto_pings_lambda.aws_s3_bucket_lifecycle_configuration.this[0]
}

moved {
  from = aws_s3_bucket.faqs_lambda
  to   = module.faqs_lambda.aws_s3_bucket.this
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.faqs_lambda
  to   = module.faqs_lambda.aws_s3_bucket_server_side_encryption_configuration.this
}

moved {
  from = aws_s3_bucket_public_access_block.faqs_lambda
  to   = module.faqs_lambda.aws_s3_bucket_public_access_block.this
}

moved {
  from = aws_s3_bucket_ownership_controls.faqs_lambda
  to   = module.faqs_lambda.aws_s3_bucket_ownership_controls.this
}

moved {
  from = aws_s3_bucket_versioning.faqs_lambda
  to   = module.faqs_lambda.aws_s3_bucket_versioning.this[0]
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.faqs_lambda
  to   = module.faqs_lambda.aws_s3_bucket_lifecycle_configuration.this[0]
}

moved {
  from = aws_s3_bucket.auto_faqs_lambda
  to   = module.auto_faqs_lambda.aws_s3_bucket.this
}

moved {
  from = aws_s3_bucket_server_side_encryption_configuration.auto_faqs_lambda
  to   = module.auto_faqs_lambda.aws_s3_bucket_server_side_encryption_configuration.this
}

moved {
  from = aws_s3_bucket_public_access_block.auto_faqs_lambda
  to   = module.auto_faqs_lambda.aws_s3_bucket_public_access_block.this
}

moved {
  from = aws_s3_bucket_ownership_controls.auto_faqs_lambda
  to   = module.auto_faqs_lambda.aws_s3_bucket_ownership_controls.this
}

moved {
  from = aws_lambda_function.users
  to   = module.lambda_users.aws_lambda_function.this
}

moved {
  from = aws_cloudwatch_log_group.users
  to   = module.lambda_users.aws_cloudwatch_log_group.this
}

moved {
  from = aws_lambda_permission.users
  to   = module.lambda_users.aws_lambda_permission.this
}

moved {
  from = aws_apigatewayv2_integration.users
  to   = module.lambda_users.aws_apigatewayv2_integration.this
}

moved {
  from = aws_apigatewayv2_route.users
  to   = module.lambda_users.aws_apigatewayv2_route.this["POST /users"]
}

moved {
  from = aws_lambda_function.auto_pings
  to   = module.lambda_auto_pings.aws_lambda_function.this
}

moved {
  from = aws_cloudwatch_log_group.auto_pings
  to   = module.lambda_auto_pings.aws_cloudwatch_log_group.this
}

moved {
  from = aws_lambda_permission.auto_pings
  to   = module.lambda_auto_pings.aws_lambda_permission.this
}

moved {
  from = aws_apigatewayv2_integration.auto_pings
  to   = module.lambda_auto_pings.aws_apigatewayv2_integration.this
}

moved {
  from = aws_apigatewayv2_route.auto_pings_all
  to   = module.lambda_auto_pings.aws_apigatewayv2_route.this["GET /auto-pings/all"]
}

moved {
  from = aws_apigatewayv2_route.auto_pings_add
  to   = module.lambda_auto_pings.aws_apigatewayv2_route.this["PUT /auto-pings/users"]
}

moved {
  from = aws_apigatewayv2_route.auto_pings_delete
  to   = module.lambda_auto_pings.aws_apigatewayv2_route.this["DELETE /auto-pings/users"]
}

moved {
  from = aws_lambda_function.faqs
  to   = module.lambda_faqs.aws_lambda_function.this
}

moved {
  from = aws_cloudwatch_log_group.faqs
  to   = module.lambda_faqs.aws_cloudwatch_log_group.this
}

moved {
  from = aws_lambda_permission.faqs
  to   = module.lambda_faqs.aws_lambda_permission.this
}

moved {
  from = aws_apigatewayv2_integration.faqs
  to   = module.lambda_faqs.aws_apigatewayv2_integration.this
}

moved {
  from = aws_apigatewayv2_route.faqs
  to   = module.lambda_faqs.aws_apigatewayv2_route.this["POST /faqs"]
}

moved {
  from = aws_lambda_function.auto_faqs
  to   = module.lambda_auto_faqs.aws_lambda_function.this
}

moved {
  from = aws_cloudwatch_log_group.auto_faqs
  to   = module.lambda_auto_faqs.aws_cloudwatch_log_group.this
}

moved {
  from = aws_lambda_permission.auto_faqs
  to   = module.lambda_auto_faqs.aws_lambda_permission.this
}

moved {
  from = aws_apigatewayv2_integration.auto_faqs
  to   = module.lambda_auto_faqs.aws_apigatewayv2_integration.this
}

moved {
  from = aws_apigatewayv2_route.auto_faqs
  to   = module.lambda_auto_faqs.aws_apigatewayv2_route.this["POST /auto-faqs"]
}

moved {
  from = aws_lambda_function.gh_hooks
  to   = module.lambda_gh_hooks.aws_lambda_function.this
}

moved {
  from = aws_cloudwatch_log_group.gh_hooks
  to   = module.lambda_gh_hooks.aws_cloudwatch_log_group.this
}

moved {
  from = aws_lambda_permission.gh_hooks
  to   = module.lambda_gh_hooks.aws_lambda_permission.this
}

moved {
  from = aws_apigatewayv2_integration.gh_hooks
  to   = module.lambda_gh_hooks.aws_apigatewayv2_integration.this
}

moved {
  from = aws_apigatewayv2_route.gh_hooks
  to   = module.lambda_gh_hooks.aws_apigatewayv2_route.this["POST /gh-hooks"]
}

moved {
  from = aws_lambda_function.gh_oauth
  to   = module.lambda_gh_oauth.aws_lambda_function.this
}

moved {
  from = aws_cloudwatch_log_group.gh_oauth
  to   = module.lambda_gh_oauth.aws_cloudwatch_log_group.this
}

moved {
  from = aws_lambda_permission.gh_oauth
  to   = module.lambda_gh_oauth.aws_lambda_permission.this
}

moved {
  from = aws_apigatewayv2_integration.gh_oauth
  to   = module.lambda_gh_oauth.aws_apigatewayv2_integration.this
}

moved {
  from = aws_apigatewayv2_route.gh_oauth
  to   = module.lambda_gh_oauth.aws_apigatewayv2_route.this["GET /gh-oauth"]
}
