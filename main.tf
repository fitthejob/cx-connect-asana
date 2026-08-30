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
}

module "asana_flow_module" {
  source = "./modules/asana-flow-module"

  environment         = var.environment
  connect_instance_id = data.terraform_remote_state.connect-terraform.outputs.connect_instance_id
}


