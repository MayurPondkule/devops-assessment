# =============================================================================
# VexarDrive Fleet Ping Service — Terraform Variables
# =============================================================================

# --- General ---
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "vexar"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "centralindia"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# --- Networking ---
variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

# --- Database ---
variable "db_sku_name" {
  description = "SKU for Azure PostgreSQL Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"  # Burstable for dev, GP for prod
}

variable "db_storage_mb" {
  description = "Storage size for PostgreSQL in MB"
  type        = number
  default     = 32768  # 32 GB
}

variable "db_backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "db_geo_redundant_backup" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}

variable "db_ha_mode" {
  description = "High availability mode for PostgreSQL (Disabled, ZoneRedundant, SameZone)"
  type        = string
  default     = "Disabled"
}

variable "db_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "vexaradmin"
}

# --- Container App ---
variable "container_image" {
  description = "Container image for the Fleet Ping Service"
  type        = string
  default     = "vexaracr.azurecr.io/fleet-ping-service:latest"
}

variable "container_min_replicas" {
  description = "Minimum number of container replicas"
  type        = number
  default     = 0
}

variable "container_max_replicas" {
  description = "Maximum number of container replicas"
  type        = number
  default     = 2
}

variable "container_cpu" {
  description = "CPU allocation for the container (in cores)"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memory allocation for the container (e.g., '1Gi')"
  type        = string
  default     = "1Gi"
}

# --- Key Vault ---
variable "jwt_secret" {
  description = "JWT secret for token signing (stored in Key Vault)"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email address for critical alert notifications"
  type        = string
  default     = "ops@vexardrive.com"
}
