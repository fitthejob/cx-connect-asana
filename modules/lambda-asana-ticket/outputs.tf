output "function_arn" {
  description = "asana-ticket Lambda ARN"
  value       = aws_lambda_function.asana_ticket.arn
}

output "alias_arn" {
  description = "asana-ticket Lambda alias ARN -- reference this from the Asana flow module's InvokeLambdaFunction action"
  value       = aws_lambda_alias.asana_ticket_live.arn
}

output "asana_secrets_arn" {
  description = "Secrets Manager secret ARN holding the Asana API token -- populated out-of-band from this repo"
  value       = aws_secretsmanager_secret.asana_api_token.arn
}
