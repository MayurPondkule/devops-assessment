# =============================================================================
# Key Vault Module — Secrets Management
# =============================================================================
# Stores application secrets (DB connection string, JWT secret).
# Uses RBAC for access control (not access policies).
# Accessible only via private endpoint.
# =============================================================================

resource "azurerm_key_vault" "main" {
  name                          = "kv-${var.project_name}-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"

  # RBAC-based access control (more granular than access policies)
  enable_rbac_authorization     = true

  # Soft delete protects against accidental deletion
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true

  # No public access — private endpoint only
  public_network_access_enabled = false

  tags = var.tags
}

# --- Private Endpoint ---
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-kv-${var.project_name}"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-dns-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

# --- RBAC Role Assignments ---

# App's managed identity can read secrets
resource "azurerm_role_assignment" "app_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.managed_identity_id
}

# Deployer (Terraform service principal) can manage secrets
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.deployer_object_id
}

# --- Secrets ---

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = var.jwt_secret
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = var.db_connection_string
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_user" {
  name         = "db-user"
  value        = var.db_admin_username
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.db_admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_secrets_officer]
}

# --- Diagnostic Settings ---
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "keyvault-diagnostics"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
  }
}
