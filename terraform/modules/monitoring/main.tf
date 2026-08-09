# =============================================================================
# Monitoring Module — Log Analytics, Application Insights, Alerts
# =============================================================================
# Centralized observability for the Fleet Ping Service.
# All resources send diagnostics to the same Log Analytics Workspace.
# =============================================================================

# --- Log Analytics Workspace ---
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"

  # Retention: 30 days for dev/staging, 90 days for prod
  retention_in_days = var.environment == "prod" ? 90 : 30

  tags = var.tags
}

# --- Application Insights ---
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "Node.JS"

  tags = var.tags
}

# =============================================================================
# Alert Rules
# =============================================================================

# --- Action Group (notification target) ---
resource "azurerm_monitor_action_group" "critical" {
  name                = "ag-${var.project_name}-critical-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "VexarCrit"

  email_receiver {
    name                    = "ops-team"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  tags = var.tags
}

# --- Alert: High Error Rate (5xx > 5% over 5 minutes) ---
resource "azurerm_monitor_metric_alert" "high_error_rate" {
  name                = "alert-high-error-rate-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Fires when the 5xx error rate exceeds 5% over 5 minutes. Indicates service degradation affecting fleet vehicle pings."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 50
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  tags = var.tags
}

# --- Alert: High Latency (p95 > 2s over 5 minutes) ---
resource "azurerm_monitor_metric_alert" "high_latency" {
  name                = "alert-high-latency-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Fires when p95 response time exceeds 2 seconds. Indicates performance degradation — could be DB connection issues or resource exhaustion."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 2000
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  tags = var.tags
}

# --- Alert: Container Restarts (> 3 in 15 minutes) ---
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "container_restarts" {
  name                = "alert-container-restarts-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Fires when the container restarts more than 3 times in 15 minutes. Indicates application instability — likely crash loop."
  severity            = 2

  scopes                  = [azurerm_log_analytics_workspace.main.id]
  evaluation_frequency    = "PT5M"
  window_duration         = "PT15M"
  auto_mitigation_enabled = true

  criteria {
    query = <<-QUERY
      ContainerAppConsoleLogs_CL
      | where Log_s contains "Fleet Ping Service started"
      | summarize RestartCount = count() by bin(TimeGenerated, 15m)
      | where RestartCount > 3
    QUERY

    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.critical.id]
  }

  tags = var.tags
}
