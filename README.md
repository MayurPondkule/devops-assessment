# VexarDrive Fleet Ping Service

Production-readiness assessment for the VexarDrive DevOps & Cloud Infrastructure Engineer role.

## Overview

Fleet Ping Service is a Node.js/Express REST API for receiving vehicle location pings and providing authenticated administrative APIs.

The solution includes:

- Containerized Node.js application
- PostgreSQL database
- JWT authentication
- OTP-based demo authentication
- Health and readiness endpoints
- Docker Compose for local development
- Terraform-based Azure infrastructure
- Azure Container Apps deployment
- Azure Container Registry
- Azure Database for PostgreSQL Flexible Server
- Azure Key Vault
- User-assigned Managed Identity
- Azure Virtual Network and private PostgreSQL connectivity
- Log Analytics / Azure Monitor
- GitHub Actions CI/CD
- Dependency and secret scanning
- Container vulnerability scanning

---

## Architecture

### Production Architecture

```mermaid
flowchart TB

    Client["Users / API Clients"]

    Client -->|HTTPS| CA["Azure Container Apps<br/>HTTPS Ingress"]

    subgraph Azure["Azure"]

        CA --> API["Fleet Ping API<br/>Node.js / Express"]

        ACR["Azure Container Registry"]
        ACR -->|Pull Image| API

        MI["User Assigned<br/>Managed Identity"]
        MI -->|AcrPull| ACR
        MI -->|Read Secrets| KV["Azure Key Vault"]

        API -->|Managed Identity| KV

        subgraph VNet["Azure Virtual Network"]

            API -->|Private Network| PG["Azure Database for<br/>PostgreSQL Flexible Server"]

            DNS["Private DNS Zone"]
            DNS --> PG

        end

        API --> LA["Log Analytics<br/>Azure Monitor"]

    end