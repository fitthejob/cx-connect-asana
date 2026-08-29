output "asana_ticket_function_arn" {
  description = "asana-ticket Lambda ARN"
  value       = module.lambda_asana_ticket.function_arn
}

output "asana_ticket_alias_arn" {
  description = "asana-ticket Lambda alias ARN -- reference this from the Asana flow module's InvokeLambdaFunction action"
  value       = module.lambda_asana_ticket.alias_arn
}

output "asana_contact_flow_module_id" {
  description = "Contact flow module ID of the Asana self-service module -- reference this from connect-terraform's main inbound flow generator via InvokeFlowModuleActionBuilder"
  value       = module.asana_flow_module.contact_flow_module_id
}

output "asana_secrets_arn" {
  description = "Secrets Manager secret ARN holding the Asana API token -- populated out-of-band"
  value       = module.lambda_asana_ticket.asana_secrets_arn
}
