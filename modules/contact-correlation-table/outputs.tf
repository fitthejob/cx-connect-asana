output "table_name" {
  description = "DynamoDB table name for contactId -> Asana task GID correlation"
  value       = aws_dynamodb_table.contact_correlation.name
}

output "table_arn" {
  description = "DynamoDB table ARN for contactId -> Asana task GID correlation"
  value       = aws_dynamodb_table.contact_correlation.arn
}
