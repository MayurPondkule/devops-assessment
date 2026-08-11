variable "location" {
  type    = string
  default = "Central India"
}


variable "environment" {

  type    = string
  default = "dev"

  validation {

    condition = contains(
      ["dev", "staging", "prod"],
      var.environment
    )

    error_message = "environment must be dev, staging, or prod."
  }
}


variable "project_name" {
  type    = string
  default = "vexar-fleet"
}


variable "container_image" {

  type = string

  description = "Full immutable container image reference."

  default = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}


variable "container_cpu" {
  type    = number
  default = 0.5
}


variable "container_memory" {
  type    = string
  default = "1Gi"
}


variable "min_replicas" {
  type    = number
  default = 1
}


variable "max_replicas" {
  type    = number
  default = 5
}


variable "postgres_sku" {
  type    = string
  default = "B_Standard_B1ms"
}


variable "postgres_version" {
  type    = string
  default = "17"
}


variable "postgres_storage_mb" {
  type    = number
  default = 32768
}


variable "postgres_backup_retention_days" {
  type    = number
  default = 7
}


variable "tags" {
  type    = map(string)
  default = {}
}

variable "demo_otp" {
  type        = string
  description = "Assessment/demo OTP. Replace with a real OTP provider in production."
  sensitive   = true
}