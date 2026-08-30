variable "environment" {
  description = "Deployment environment (e.g dev, staging, prod)"
  type        = string
}

variable "s3_bucket_lambda_artifacts" {
  description = "S3 bucket for Amazon Connect Lambda artifacts"
  type        = string
}

variable "artifact_sha" {
  description = "Git commit SHA the asana-ticket Lambda artifact zip is keyed by"
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

variable "contact_correlation_table_name" {
  description = "DynamoDB table name for contactId -> Asana task GID correlation"
  type        = string
}

variable "recording_transcribe_function_name" {
  description = "Name of the recording-transcribe Lambda"
  type        = string
}

variable "recording_bucket_name" {
  description = "S3 bucket Amazon Connect writes call recordings to"
  type        = string
}

variable "recording_bucket_prefix" {
  description = "S3 key prefix to scope the recording-transcribe trigger to IVR-only recordings"
  type        = string
  default     = "connect/mini-connect/CallRecordings/ivr/"
}

variable "transcript_update_function_name" {
  description = "Name of the asana-transcript-update Lambda"
  type        = string
}
