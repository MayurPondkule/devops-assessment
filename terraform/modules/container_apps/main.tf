# =============================================================================
# Container Apps Module — Application Compute
# =============================================================================
# Azure Container Apps for running the Fleet Ping Service.
# Chosen over AKS for:
#   - Single-service simplicity (no cluster management overhead)
#   - Built-in autoscaling based on HTTP traffic
#   - Scale-to-zero for cost optimization (fleet pings are bursty)
#   - Managed TLS ingress
#   - Built-in observability via Log Analytics
# =============================================================================

# --- Container Apps Environment ---
resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.project_name}-${var.environment}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_id
  infrastructure_subnet_id   = var.subnet_id

  tags = var.tags
}

# --- Container App ---
resource "azurerm_container_app" "fleet_ping" {
  name                         = "ca-fleet-ping-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Multiple"  # Enables blue-green / canary deployments

  tags = var.tags

  # --- Managed Identity ---
  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  # --- Container Registry Authentication ---
  registry {
    server   = "vexaracr.azurecr.io"
    identity = var.managed_identity_id
  }

  # --- Ingress ---
  ingress {
    external_enabled = true
    target_port      = 3000
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  # --- Template ---
  template {
    min_replicas = var.container_min_replicas
    max_replicas = var.container_max_replicas

    container {
      name   = "fleet-ping-service"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      # --- Environment Variables (non-sensitive) ---
      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name  = "PORT"
        value = "3000"
      }

      env {
        name  = "DB_HOST"
        value = var.db_host
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }

      env {
        name  = "DB_SSL"
        value = "true"
      }

      env {
        name  = "DB_POOL_MIN"
        value = "2"
      }

      env {
        name  = "DB_POOL_MAX"
        value = "20"
      }

      env {
        name  = "LOG_LEVEL"
        value = var.environment == "prod" ? "info" : "debug"
      }

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = var.app_insights_conn_str
      }

      # --- Secrets from Key Vault (via managed identity) ---
      env {
        name        = "DB_USER"
        secret_name = "db-user"
      }

      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }

      env {
        name        = "JWT_SECRET"
        secret_name = "jwt-secret"
      }

      # --- Health Probes ---
      liveness_probe {
        transport = "HTTP"
        path      = "/healthz"
        port      = 3000

        initial_delay    = 5
        interval_seconds = 30
        timeout          = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/readyz"
        port      = 3000

        interval_seconds = 10
        timeout          = 5
        failure_count_threshold = 3
      }

      startup_probe {
        transport = "HTTP"
        path      = "/healthz"
        port      = 3000

        interval_seconds = 5
        timeout          = 3
        failure_count_threshold = 10
      }
    }

    # --- Autoscale Rule ---
    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = 50  # Scale up when > 50 concurrent requests per replica
    }
  }

  # --- Secrets (referenced by env vars above) ---
  secret {
    name                = "db-user"
    key_vault_secret_id = "${var.keyvault_uri}secrets/db-user"
    identity            = var.managed_identity_id
  }

  secret {
    name                = "db-password"
    key_vault_secret_id = "${var.keyvault_uri}secrets/db-password"
    identity            = var.managed_identity_id
  }

  secret {
    name                = "jwt-secret"
    key_vault_secret_id = "${var.keyvault_uri}secrets/jwt-secret"
    identity            = var.managed_identity_id
  }
}
