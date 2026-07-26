import {
  to = aws_s3_bucket.state
  id = module.bootstrap_config.state_bucket
}

import {
  to = aws_s3_bucket_versioning.state
  id = module.bootstrap_config.state_bucket
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.state
  id = module.bootstrap_config.state_bucket
}

import {
  to = aws_s3_bucket_public_access_block.state
  id = module.bootstrap_config.state_bucket
}

import {
  to = aws_s3_bucket_ownership_controls.state
  id = module.bootstrap_config.state_bucket
}
