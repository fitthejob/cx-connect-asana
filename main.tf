data "terraform_remote_state" "connect-terraform" {
  backend = "s3"

  config = {
    bucket       = "amazon-connect-tfstate-nevs-cloud-prod"
    key          = "connect/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

module "lambda_asana_ticket" {
  source = "./modules/lambda-asana-ticket"

  environment                = var.environment
  function_name              = var.asana_ticket_function_name
  s3_bucket_lambda_artifacts = var.s3_bucket_lambda_artifacts
  s3_key                     = "asana-ticket/dev/asana-ticket-${var.artifact_sha}.zip"
  layer_arn                  = data.terraform_remote_state.connect-terraform.outputs.shared_deps_layer_arn
  asana_project_gid          = var.asana_project_gid
  correlation_table_name     = module.contact_correlation_table.table_name
  correlation_table_arn      = module.contact_correlation_table.table_arn
}

module "asana_flow_module" {
  source = "./modules/asana-flow-module"

  environment         = var.environment
  connect_instance_id = data.terraform_remote_state.connect-terraform.outputs.connect_instance_id
}

module "contact_correlation_table" {
  source = "./modules/contact-correlation-table"

  table_name = var.contact_correlation_table_name
}

module "lambda_recording_transcribe" {
  source = "./modules/lambda-recording-transcribe"

  environment                = var.environment
  function_name              = var.recording_transcribe_function_name
  s3_bucket_lambda_artifacts = var.s3_bucket_lambda_artifacts
  s3_key                     = "recording-transcribe/dev/recording-transcribe-${var.artifact_sha}.zip"
  layer_arn                  = data.terraform_remote_state.connect-terraform.outputs.shared_deps_layer_arn
  recording_bucket_name      = var.recording_bucket_name
  recording_bucket_prefix    = var.recording_bucket_prefix
  correlation_table_name     = module.contact_correlation_table.table_name
  correlation_table_arn      = module.contact_correlation_table.table_arn
}

module "lambda_asana_transcript_update" {
  source = "./modules/lambda-asana-transcript-update"

  environment                = var.environment
  function_name              = var.transcript_update_function_name
  s3_bucket_lambda_artifacts = var.s3_bucket_lambda_artifacts
  s3_key                     = "transcript-update/dev/transcript-update-${var.artifact_sha}.zip"
  layer_arn                  = data.terraform_remote_state.connect-terraform.outputs.shared_deps_layer_arn
  recording_bucket_name      = var.recording_bucket_name
  correlation_table_name     = module.contact_correlation_table.table_name
  correlation_table_arn      = module.contact_correlation_table.table_arn
  asana_secret_arn           = module.lambda_asana_ticket.asana_secrets_arn
}

