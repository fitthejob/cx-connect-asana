variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod) -- suffixed onto IAM role/policy names"
  type        = string
}

variable "function_name" {
  description = "Name of the asana-transcript-update Lambda"
  type        = string
}

variable "s3_bucket_lambda_artifacts" {
  description = "S3 bucket for Amazon Connect Lambda artifacts"
  type        = string
}

variable "s3_key" {
  description = "S3 key for the asana-transcript-update Lambda artifact zip"
  type        = string
}

variable "layer_arn" {
  description = "ARN of connect-terraform's shared Lambda dependencies layer"
  type        = string
}

variable "recording_bucket_name" {
  description = "S3 bucket Transcribe writes completed transcript JSON to (same bucket Connect writes recordings to)"
  type        = string
}

variable "correlation_table_name" {
  description = "DynamoDB table name for contactId -> Asana task GID correlation"
  type        = string
}

variable "correlation_table_arn" {
  description = "DynamoDB table ARN for contactId -> Asana task GID correlation"
  type        = string
}

variable "asana_secret_arn" {
  description = "Secrets Manager secret ARN holding the Asana API token (owned by the lambda-asana-ticket module, reused here)"
  type        = string
}
