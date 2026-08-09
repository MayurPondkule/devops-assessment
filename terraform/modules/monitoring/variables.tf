variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "project_name" { type = string }
variable "environment" { type = string }
variable "alert_email" { type = string; description = "Email address for critical alert notifications" }
variable "tags" { type = map(string) }
