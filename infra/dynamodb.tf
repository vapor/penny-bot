resource "aws_dynamodb_table" "penny_user" {
  name         = "penny-user-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

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
    hash_key        = "discordID"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GH-ID-GSI"
    hash_key        = "githubID"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "penny_coin" {
  name         = "penny-coin-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  range_key    = "createdAt"

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
    hash_key        = "fromUserID"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "TU-ID-GSI"
    hash_key        = "toUserID"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "ghhooks_message_lookup" {
  name         = "ghHooks-message-lookup-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}
