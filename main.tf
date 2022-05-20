provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      hashicorp-learn = "learn-terraform-aws-dynamodb"
    }
  }
}

resource "random_pet" "table_name" {
  prefix    = "environment"
  separator = "_"
  length    = 4
}

resource "aws_dynamodb_table" "environment" {
  name         = random_pet.table_name.id
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "deviceId"
  range_key = "epochS"

  attribute {
    name = "deviceId"
    type = "S"
  }

  attribute {
    name = "epochS"
    type = "N"
  }
}
