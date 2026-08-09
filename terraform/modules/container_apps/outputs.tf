output "app_url" {
  description = "URL of the Container App"
  value       = "https://${azurerm_container_app.fleet_ping.ingress[0].fqdn}"
}

output "app_id" {
  description = "ID of the Container App"
  value       = azurerm_container_app.fleet_ping.id
}

output "environment_id" {
  description = "ID of the Container Apps Environment"
  value       = azurerm_container_app_environment.main.id
}
