output "resource_group_name" {
  value = azurerm_resource_group.this.name
}


output "container_registry_login_server" {
  value = azurerm_container_registry.this.login_server
}


output "container_app_fqdn" {
  value = azurerm_container_app.this.ingress[0].fqdn
}


output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}


output "key_vault_name" {
  value = azurerm_key_vault.this.name
}