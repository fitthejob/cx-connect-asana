output "function_arn" {
  description = "recording-transcribe Lambda ARN"
  value       = aws_lambda_function.recording_transcribe.arn
}
