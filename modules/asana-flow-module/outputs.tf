output "contact_flow_module_id" {
  description = "Contact flow module ID of the Asana self-service module -- reference this from connect-terraform's main inbound flow generator via InvokeFlowModuleActionBuilder"
  value       = aws_connect_contact_flow_module.asana_integration.id
}
