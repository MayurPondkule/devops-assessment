# =============================================================================
# VexarDrive Fleet Ping Service — Terraform Outputs
# =============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "container_app_url" {
  description = "URL of the Container App"
  value       = module.container_apps.app_url
}

output "postgresql_server_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server"
  value       = module.database.server_fqdn
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.keyvault.vault_uri
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = module.monitoring.log_analytics_workspace_id
}

output "managed_identity_client_id" {
  description = "Client ID of the managed identity"
  value       = module.identity.managed_identity_client_id
}

output "acr_login_server" {
  description = "Login server URL of the Azure Container Registry"
  value       = azurerm_container_registry.main.login_server
}
