variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod) -- suffixed onto IAM role/policy names"
  type        = string
}

variable "function_name" {
  description = "Name of the asana-ticket Lambda"
  type        = string
}

variable "s3_bucket_lambda_artifacts" {
  description = "S3 bucket for Amazon Connect Lambda artifacts"
  type        = string
}

variable "s3_key" {
  description = "S3 key for the asana-ticket Lambda artifact zip"
  type        = string
}

variable "layer_arn" {
  description = "ARN of connect-terraform's shared Lambda dependencies layer"
  type        = string
}

variable "asana_project_gid" {
  description = "Asana project GID that self-service tickets are created in"
  type        = string
}
