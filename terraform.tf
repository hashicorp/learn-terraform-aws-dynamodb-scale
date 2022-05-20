terraform {
  cloud {
    workspaces {
      name = "learn-terraform-aws-dynamodb"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.15.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.2.0"
    }
  }

  required_version = "~> 1.2"
}