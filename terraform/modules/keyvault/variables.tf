variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project_name" { type = string }
variable "environment" { type = string }
variable "tenant_id" { type = string }
variable "managed_identity_id" { type = string }
variable "deployer_object_id" { type = string }
variable "subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "log_analytics_id" { type = string }
variable "jwt_secret" { type = string; sensitive = true }
variable "db_connection_string" { type = string; sensitive = true }
variable "db_admin_username" { type = string }
variable "db_admin_password" { type = string; sensitive = true }
variable "tags" { type = map(string) }
