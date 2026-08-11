locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = merge(var.tags, {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  })
}

data "azurerm_client_config" "current" {}

# ------------------------------------------------------------
# Resource Group
# ------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = "${local.name}-rg"
  location = var.location
  tags     = local.common_tags
}

# ------------------------------------------------------------
# Log Analytics
# ------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.name}-logs"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = local.common_tags
}

# ------------------------------------------------------------
# Container Registry
# ------------------------------------------------------------

resource "azurerm_container_registry" "this" {
  name = replace(
    "${var.project_name}${var.environment}acr",
    "-",
    ""
  )

  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  sku           = "Basic"
  admin_enabled = false

  tags = local.common_tags
}

# ------------------------------------------------------------
# Managed Identity
# ------------------------------------------------------------

resource "azurerm_user_assigned_identity" "container_app" {
  name                = "${local.name}-identity"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  tags = local.common_tags
}

# ------------------------------------------------------------
# ACR Pull Permission
# ------------------------------------------------------------

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"

  principal_id = azurerm_user_assigned_identity.container_app.principal_id
}

# ------------------------------------------------------------
# Key Vault
# ------------------------------------------------------------

resource "azurerm_key_vault" "this" {
  name = replace(
    "${var.project_name}${var.environment}kv",
    "-",
    ""
  )

  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  rbac_authorization_enabled = true

  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  public_network_access_enabled = true

  tags = local.common_tags
}

# ------------------------------------------------------------
# Key Vault Permission
# ------------------------------------------------------------

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"

  principal_id = azurerm_user_assigned_identity.container_app.principal_id
}

# ------------------------------------------------------------
# Random Database Password
# ------------------------------------------------------------

resource "random_password" "postgres" {
  length           = 32
  special          = true
  override_special = "_%@"
}

# ------------------------------------------------------------
# Random JWT Secret
# ------------------------------------------------------------

resource "random_password" "jwt" {
  length  = 64
  special = true
}

# ------------------------------------------------------------
# Key Vault DB Password
# ------------------------------------------------------------

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.postgres.result
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [
    azurerm_role_assignment.key_vault_secrets_user
  ]
}

# ------------------------------------------------------------
# Key Vault JWT Secret
# ------------------------------------------------------------

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = random_password.jwt.result
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [
    azurerm_role_assignment.key_vault_secrets_user
  ]
}

# ------------------------------------------------------------
# Key Vault Demo OTP
# ------------------------------------------------------------

resource "azurerm_key_vault_secret" "demo_otp" {
  name         = "demo-otp"
  value        = var.demo_otp
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [
    azurerm_role_assignment.key_vault_secrets_user
  ]
}

# ------------------------------------------------------------
# Virtual Network
# ------------------------------------------------------------

resource "azurerm_virtual_network" "this" {
  name                = "${local.name}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  address_space = [
    "10.20.0.0/16"
  ]

  tags = local.common_tags
}

# ------------------------------------------------------------
# Container Apps Subnet
# ------------------------------------------------------------

resource "azurerm_subnet" "container_apps" {
  name                 = "container-apps"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes = [
    "10.20.0.0/23"
  ]

  delegation {
    name = "container-apps-delegation"

    service_delegation {
      name = "Microsoft.App/environments"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# ------------------------------------------------------------
# PostgreSQL Subnet
# ------------------------------------------------------------

resource "azurerm_subnet" "postgres" {
  name                 = "postgres"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name

  address_prefixes = [
    "10.20.10.0/24"
  ]

  delegation {
    name = "postgres-delegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# ------------------------------------------------------------
# PostgreSQL Private DNS
# ------------------------------------------------------------

resource "azurerm_private_dns_zone" "postgres" {
  name                = "${local.name}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.this.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${local.name}-postgres-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.this.id
  resource_group_name   = azurerm_resource_group.this.name
}

# ------------------------------------------------------------
# PostgreSQL Flexible Server
# ------------------------------------------------------------

resource "azurerm_postgresql_flexible_server" "this" {
  name                = "${local.name}-pg"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location

  version = var.postgres_version
  zone    = "1"

  delegated_subnet_id = azurerm_subnet.postgres.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  public_network_access_enabled = false

  administrator_login    = "vexaradmin"
  administrator_password = random_password.postgres.result

  storage_mb            = var.postgres_storage_mb
  sku_name              = var.postgres_sku
  backup_retention_days = var.postgres_backup_retention_days

  tags = local.common_tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres
  ]
}

# ------------------------------------------------------------
# Database
# ------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_database" "fleet" {
  name      = "vexar_fleet"
  server_id = azurerm_postgresql_flexible_server.this.id

  charset   = "UTF8"
  collation = "en_US.utf8"
}

# ------------------------------------------------------------
# Container Apps Environment
# ------------------------------------------------------------

resource "azurerm_container_app_environment" "this" {
  name                = "${local.name}-cae"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  infrastructure_subnet_id = azurerm_subnet.container_apps.id

  tags = local.common_tags
}

# ------------------------------------------------------------
# Container App
# ------------------------------------------------------------

resource "azurerm_container_app" "this" {
  name                         = "${local.name}-app"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id

  revision_mode = "Single"

  # ----------------------------------------------------------
  # Managed Identity
  # ----------------------------------------------------------

  identity {
    type = "UserAssigned"

    identity_ids = [
      azurerm_user_assigned_identity.container_app.id
    ]
  }

  # ----------------------------------------------------------
  # Container Registry
  # ----------------------------------------------------------

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.container_app.id
  }

  # ----------------------------------------------------------
  # Key Vault Secrets
  # ----------------------------------------------------------

  secret {
    name                = "db-password"
    key_vault_secret_id = azurerm_key_vault_secret.db_password.versionless_id
    identity            = azurerm_user_assigned_identity.container_app.id
  }

  secret {
    name                = "jwt-secret"
    key_vault_secret_id = azurerm_key_vault_secret.jwt_secret.versionless_id
    identity            = azurerm_user_assigned_identity.container_app.id
  }

  secret {
    name                = "demo-otp"
    key_vault_secret_id = azurerm_key_vault_secret.demo_otp.versionless_id
    identity            = azurerm_user_assigned_identity.container_app.id
  }

  # ----------------------------------------------------------
  # Container Template
  # ----------------------------------------------------------

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "fleet-api"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      # ------------------------------------------------------
      # Environment
      # ------------------------------------------------------

      env {
        name  = "NODE_ENV"
        value = "production"
      }


      env {
        name  = "PORT"
        value = "3000"
      }

      # ------------------------------------------------------
      # Database
      # ------------------------------------------------------

      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.this.fqdn
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      env {
        name  = "DB_USER"
        value = "vexaradmin"
      }

      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }

      env {
        name  = "DB_NAME"
        value = "vexar_fleet"
      }

      env {
        name  = "DB_SSL"
        value = "true"
      }

      env {
        name  = "DB_SSL_REJECT_UNAUTHORIZED"
        value = "true"
      }

      # ------------------------------------------------------
      # JWT
      # ------------------------------------------------------

      env {
        name        = "JWT_SECRET"
        secret_name = "jwt-secret"
      }

      env {
        name  = "JWT_EXPIRES_IN"
        value = "1h"
      }

      env {
        name        = "DEMO_OTP"
        secret_name = "demo-otp"
      }

      # ------------------------------------------------------
      # Liveness Probe
      # ------------------------------------------------------

      liveness_probe {
        transport = "HTTP"
        port      = 3000
        path      = "/health"
      }

      # ------------------------------------------------------
      # Readiness Probe
      # ------------------------------------------------------

      readiness_probe {
        transport = "HTTP"
        port      = 3000
        path      = "/ready"
      }
    }

    # --------------------------------------------------------
    # Autoscaling
    # --------------------------------------------------------

    http_scale_rule {
      name                = "http-scale"
      concurrent_requests = 100
    }
  }

  # ----------------------------------------------------------
  # Public HTTPS Ingress
  # ----------------------------------------------------------

  ingress {
    external_enabled = true

    target_port = 3000
    transport   = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = local.common_tags

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.key_vault_secrets_user,
    azurerm_postgresql_flexible_server_database.fleet
  ]
}