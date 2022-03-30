terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.2"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "random_pet" "table_name" {
  prefix    = "environment"
  separator = "_"
  length    = 4
}

resource "aws_dynamodb_table" "environment" {
  name         = random_pet.table_name.id
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "deviceId"
    type = "S"
  }

  attribute {
    name = "eventId"
    type = "S"
  }

  hash_key  = "deviceId"
  range_key = "eventId"
}
