output "managed_identity_id" {
  description = "Resource ID of the managed identity"
  value       = azurerm_user_assigned_identity.app.id
}

output "managed_identity_principal_id" {
  description = "Principal ID (object ID) of the managed identity"
  value       = azurerm_user_assigned_identity.app.principal_id
}

output "managed_identity_client_id" {
  description = "Client ID of the managed identity"
  value       = azurerm_user_assigned_identity.app.client_id
}
