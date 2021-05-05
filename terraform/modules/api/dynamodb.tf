resource "aws_dynamodb_table" "events_table" {
  name           = var.table_name
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "eventId"

  attribute {
    name = "eventId"
    type = "S"
  }

  attribute {
    name = "createdBy"
    type = "S"
  }

  global_secondary_index {
    name            = "CreatedByIndex"
    read_capacity   = 1
    write_capacity  = 1
    hash_key        = "createdBy"
    projection_type = "ALL"

  }

  tags = {
    Name        = "events table"
    Environment = var.stage
  }
}
