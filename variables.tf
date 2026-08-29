variable "environment" {
  description = "Deployment environment (e.g dev, staging, prod)"
  type        = string
}

variable "s3_bucket_lambda_artifacts" {
  description = "S3 bucket for Amazon Connect Lambda artifacts"
  type        = string
}

variable "asana_ticket_s3_key" {
  description = "S3 key for the asana-ticket Lambda artifact zip"
  type        = string
}

variable "asana_ticket_function_name" {
  description = "Name of the asana-ticket Lambda"
  type        = string
}

variable "asana_project_gid" {
  description = "Asana project GID that self-service tickets are created in"
  type        = string
}
