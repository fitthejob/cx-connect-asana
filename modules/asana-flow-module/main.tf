resource "aws_connect_contact_flow_module" "asana_integration" {
  instance_id = var.connect_instance_id
  name        = "Module-AsanaIntegration-${var.environment}"
  description = "Self-service Asana integration module invoked from the main inbound flow"
  content     = file("${path.module}/contact_flows/asana_integration.json")

  lifecycle {
    prevent_destroy = true
  }
}

# CI target for validating generated asana_integration.json against the real
# Connect API (UpdateContactFlowModuleContent) before trusting it enough to
# apply to the real module resource above -- same pattern as
# connect-terraform's validation_sandbox_module.
resource "aws_connect_contact_flow_module" "validation_sandbox" {
  instance_id = var.connect_instance_id
  name        = "Validation-Sandbox-Module-Asana-${var.environment}"
  description = "CI target for validating generated Asana flow module JSON against the real Connect API"
  content     = file("${path.module}/contact_flows/validation_sandbox_module.json")
}
