variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "connect_instance_id" {
  description = "Amazon Connect instance ID, from connect-terraform's remote state"
  type        = string
}
