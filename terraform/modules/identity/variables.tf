variable "resource_group_name" { type = string }
variable "resource_group_id" { type = string }
variable "location" { type = string }
variable "project_name" { type = string }
variable "environment" { type = string }
variable "acr_id" { type = string; description = "Resource ID of the Azure Container Registry" }
variable "tags" { type = map(string) }
