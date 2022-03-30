# Output value definitions

output "environment_table_name" {
  description = "Name of the environment DynamoDB table"
  value       = aws_dynamodb_table.environment.name
}

output "environment_table_arn" {
  description = "ARN of the environment DynamoDB table"
  value       = aws_dynamodb_table.environment.arn
}
