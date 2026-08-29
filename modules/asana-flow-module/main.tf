resource "aws_connect_contact_flow_module" "asana_integration" {
  instance_id = var.connect_instance_id
  name        = "Module-AsanaIntegration-${var.environment}"
  description = "Self-service Asana integration module invoked from the main inbound flow"
  content     = file("${path.module}/contact_flows/asana_integration.json")

  lifecycle {
    prevent_destroy = true
  }
}
