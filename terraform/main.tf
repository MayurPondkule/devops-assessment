# =============================================================================
# VexarDrive Fleet Ping Service — Main Terraform Configuration
# =============================================================================
# Orchestrates all modules for the Fleet Ping Service infrastructure.
# =============================================================================

data "azurerm_client_config" "current" {}

# --- Resource Group ---
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = merge(var.tags, {
    environment = var.environment
    project     = var.project_name
    managed_by  = "terraform"
  })
}

# --- Azure Container Registry ---
resource "azurerm_container_registry" "main" {
  name                = "${var.project_name}acr${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.environment == "prod" ? "Premium" : "Basic"
  admin_enabled       = false

  tags = merge(var.tags, {
    environment = var.environment
    project     = var.project_name
    managed_by  = "terraform"
  })
}

# --- Local Values ---
locals {
  common_tags = merge(var.tags, {
    environment = var.environment
    project     = var.project_name
    managed_by  = "terraform"
  })
}

# --- Networking ---
module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
  environment         = var.environment
  vnet_address_space  = var.vnet_address_space
  tags                = local.common_tags
}

# --- Identity ---
module "identity" {
  source = "./modules/identity"

  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
  environment         = var.environment
  acr_id              = azurerm_container_registry.main.id
  tags                = local.common_tags
}

# --- Monitoring ---
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  project_name        = var.project_name
  environment         = var.environment
  alert_email         = var.alert_email
  tags                = local.common_tags
}

# --- Key Vault ---
module "keyvault" {
  source = "./modules/keyvault"

  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  project_name           = var.project_name
  environment            = var.environment
  tenant_id              = data.azurerm_client_config.current.tenant_id
  managed_identity_id    = module.identity.managed_identity_principal_id
  deployer_object_id     = data.azurerm_client_config.current.object_id
  subnet_id              = module.networking.endpoints_subnet_id
  private_dns_zone_id    = module.networking.keyvault_private_dns_zone_id
  log_analytics_id       = module.monitoring.log_analytics_workspace_id
  jwt_secret             = var.jwt_secret
  db_connection_string   = module.database.connection_string
  db_admin_username      = var.db_admin_username
  db_admin_password      = module.database.admin_password
  tags                   = local.common_tags
}

# --- Database ---
module "database" {
  source = "./modules/database"

  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  project_name             = var.project_name
  environment              = var.environment
  delegated_subnet_id      = module.networking.database_subnet_id
  private_dns_zone_id      = module.networking.postgres_private_dns_zone_id
  sku_name                 = var.db_sku_name
  storage_mb               = var.db_storage_mb
  backup_retention_days    = var.db_backup_retention_days
  geo_redundant_backup     = var.db_geo_redundant_backup
  ha_mode                  = var.db_ha_mode
  admin_username           = var.db_admin_username
  log_analytics_id         = module.monitoring.log_analytics_workspace_id
  tags                     = local.common_tags
}

# --- Container Apps ---
module "container_apps" {
  source = "./modules/container_apps"

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  project_name            = var.project_name
  environment             = var.environment
  subnet_id               = module.networking.container_apps_subnet_id
  log_analytics_id        = module.monitoring.log_analytics_workspace_id
  app_insights_conn_str   = module.monitoring.app_insights_connection_string
  managed_identity_id     = module.identity.managed_identity_id
  container_image         = var.container_image
  container_min_replicas  = var.container_min_replicas
  container_max_replicas  = var.container_max_replicas
  container_cpu           = var.container_cpu
  container_memory        = var.container_memory
  keyvault_uri            = module.keyvault.vault_uri
  db_host                 = module.database.server_fqdn
  db_name                 = module.database.database_name
  tags                    = local.common_tags
}
