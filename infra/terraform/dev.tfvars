environment = "dev"

location = "Central India"

project_name = "vexar-fleet"

container_image = "vexarfleetdevacr.azurecr.io/vexar-fleet-ping:206ab0d3e4c167674c1363d1d98c9f44bfd1aa13"

min_replicas = 1

max_replicas = 2

postgres_sku = "B_Standard_B1ms"

postgres_version = "17"

postgres_storage_mb = 32768

postgres_backup_retention_days = 7


tags = {
  owner = "devops-assessment"
}