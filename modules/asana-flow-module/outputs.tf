output "contact_flow_module_id" {
  description = "Contact flow module ID of the Asana self-service module -- reference this from connect-terraform's main inbound flow generator via InvokeFlowModuleActionBuilder"
  value       = aws_connect_contact_flow_module.asana_integration.contact_flow_module_id
}

output "validation_sandbox_module_id" {
  description = "Contact flow module ID of the Validation-Sandbox-Module-Asana module -- CI validates generated flow JSON against this before applying to the real module"
  value       = aws_connect_contact_flow_module.validation_sandbox.contact_flow_module_id
}
