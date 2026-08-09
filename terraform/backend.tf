# =============================================================================
# VexarDrive Fleet Ping Service — Terraform Backend Configuration
# =============================================================================
# Remote state storage in Azure Blob Storage.
# Each environment uses a separate state file for isolation.
#
# Prerequisites (one-time manual setup):
#   1. Create a Resource Group: rg-vexar-tfstate
#   2. Create a Storage Account: vexartfstate
#   3. Create a Container: tfstate
#   4. Enable blob versioning for state history
#
# Usage:
#   terraform init -backend-config="key=dev.terraform.tfstate"
# =============================================================================

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-vexar-tfstate"
    storage_account_name = "vexartfstate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"  # Override per environment
    use_oidc             = true
  }
}
