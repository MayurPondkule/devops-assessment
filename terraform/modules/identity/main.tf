# =============================================================================
# Identity Module — Managed Identity + RBAC
# =============================================================================
# Creates a user-assigned managed identity for the Fleet Ping Service.
# Assigns least-privilege RBAC roles for accessing Key Vault, ACR, and PostgreSQL.
# =============================================================================

# --- User-Assigned Managed Identity ---
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# --- RBAC: ACR Pull ---
# Allow the app to pull container images from Azure Container Registry.
# Scoped to the ACR resource (not the entire resource group) for least-privilege.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
