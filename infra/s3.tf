module "lambdas_store" {
  source = "./modules/bucket"

  name               = module.constants.bucket_names.lambdas_store
  versioning_enabled = true

  lifecycle_rules = {
    "lambda zip versioning" = {
      noncurrent_days           = 30
      newer_noncurrent_versions = 5
    }
  }
}

module "penny_caches" {
  source = "./modules/bucket"

  name = module.constants.bucket_names.penny_caches
}

module "auto_pings_lambda" {
  source = "./modules/bucket"

  name               = module.constants.bucket_names.auto_pings_lambda
  versioning_enabled = true

  lifecycle_rules = {
    "auto-pings-repo.json versioning" = {
      prefix                    = "auto-pings-repo.json"
      object_size_less_than     = 16 * 1024 * 1024
      noncurrent_days           = 30
      newer_noncurrent_versions = 5
    }
  }
}

module "faqs_lambda" {
  source = "./modules/bucket"

  name               = module.constants.bucket_names.faqs_lambda
  versioning_enabled = true

  lifecycle_rules = {
    "faqs-repo.json versioning" = {
      prefix                    = "faqs-repo.json"
      object_size_less_than     = 32 * 1024 * 1024
      noncurrent_days           = 30
      newer_noncurrent_versions = 5
    }
  }
}

module "auto_faqs_lambda" {
  source = "./modules/bucket"

  name = module.constants.bucket_names.auto_faqs_lambda
}
