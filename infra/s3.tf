module "lambdas_store" {
  source = "./modules/bucket"

  name = module.bootstrap_config.bucket_names.lambdas_store
}

module "penny_caches" {
  source = "./modules/bucket"

  name = module.bootstrap_config.bucket_names.penny_caches
}

module "auto_pings_lambda" {
  source = "./modules/bucket"

  name               = module.bootstrap_config.bucket_names.auto_pings_lambda
  object_ownership   = "BucketOwnerPreferred"
  versioning_enabled = true

  lifecycle_rule = {
    id                        = "auto-pings-repo.json versioning"
    prefix                    = "auto-pings-repo.json"
    object_size_less_than     = 16777216
    noncurrent_days           = 30
    newer_noncurrent_versions = 5
  }
}

module "faqs_lambda" {
  source = "./modules/bucket"

  name               = module.bootstrap_config.bucket_names.faqs_lambda
  object_ownership   = "BucketOwnerPreferred"
  versioning_enabled = true

  lifecycle_rule = {
    id                        = "faqs-repo.json versioning"
    prefix                    = "faqs-repo.json"
    object_size_less_than     = 33554432
    noncurrent_days           = 30
    newer_noncurrent_versions = 5
  }
}

module "auto_faqs_lambda" {
  source = "./modules/bucket"

  name = module.bootstrap_config.bucket_names.auto_faqs_lambda
}
