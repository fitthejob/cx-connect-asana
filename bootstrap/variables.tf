variable "lambda_artifacts_bucket" {
  description = "S3 bucket the asana-ticket Lambda artifact zip is uploaded to and deployed from"
  type        = string
}

variable "tfstate_bucket" {
  description = "S3 bucket holding this repo's own Terraform state (backend.tf's bucket)"
  type        = string
}

variable "connect_terraform_tfstate_bucket" {
  description = "S3 bucket holding connect-terraform's Terraform state, read via this repo's terraform_remote_state data source"
  type        = string
}
