output "vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}
