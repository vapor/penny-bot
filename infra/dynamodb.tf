resource "aws_dynamodb_table" "penny_user" {
  name                        = module.constants.table_names.penny_user
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true
  hash_key                    = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "discordID"
    type = "S"
  }

  attribute {
    name = "githubID"
    type = "S"
  }

  global_secondary_index {
    name            = "D-ID-GSI"
    projection_type = "ALL"

    key_schema {
      attribute_name = "discordID"
      key_type       = "HASH"
    }
  }

  global_secondary_index {
    name            = "GH-ID-GSI"
    projection_type = "ALL"

    key_schema {
      attribute_name = "githubID"
      key_type       = "HASH"
    }
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "penny_coin" {
  name                        = module.constants.table_names.penny_coin
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true
  hash_key                    = "id"
  range_key                   = "createdAt"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "N"
  }

  attribute {
    name = "fromUserID"
    type = "S"
  }

  attribute {
    name = "toUserID"
    type = "S"
  }

  global_secondary_index {
    name            = "FU-ID-GSI"
    projection_type = "ALL"

    key_schema {
      attribute_name = "fromUserID"
      key_type       = "HASH"
    }
  }

  global_secondary_index {
    name            = "TU-ID-GSI"
    projection_type = "ALL"

    key_schema {
      attribute_name = "toUserID"
      key_type       = "HASH"
    }
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "ghhooks_message_lookup" {
  name                        = module.constants.table_names.ghhooks_message_lookup
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true
  hash_key                    = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
