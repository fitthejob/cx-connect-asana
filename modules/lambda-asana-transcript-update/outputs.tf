output "function_arn" {
  description = "asana-transcript-update Lambda ARN"
  value       = aws_lambda_function.transcript_update.arn
}
