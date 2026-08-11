# VexarDrive Fleet Ping Service

Production-readiness assessment for the **VexarDrive DevOps & Cloud Infrastructure Engineer** role.

## Overview

Fleet Ping Service is a Node.js/Express REST API for receiving vehicle location pings and providing authenticated administrative APIs.

The solution demonstrates a production-oriented DevOps and cloud deployment approach using:

- Node.js / Express
- PostgreSQL
- JWT authentication
- OTP-based demo authentication
- Health and readiness endpoints
- Docker / multi-stage Docker builds
- Non-root container execution
- Docker Compose for local development
- Terraform Infrastructure as Code
- Azure Container Apps
- Azure Container Registry
- Azure Database for PostgreSQL Flexible Server
- Azure Key Vault
- User-assigned Managed Identity
- GitHub Actions CI/CD
- GitHub OIDC / federated identity
- Trivy container vulnerability scanning
- Azure Monitor / Log Analytics
- HTTPS ingress
- PostgreSQL TLS/SSL
- Immutable image deployment using Git commit SHA

---

# Architecture

## Production Architecture

```mermaid
flowchart TB

    Developer["Developer"]
    GitHub["GitHub Repository"]

    Developer -->|"Push code"| GitHub

    subgraph CICD["GitHub Actions CI/CD"]

        Test["Test<br/>Install dependencies<br/>Run tests"]

        Trivy["Trivy Security Scan<br/>HIGH / CRITICAL gate"]

        Build["Docker Build<br/>Multi-stage Dockerfile"]

        Push["Push Image<br/>Immutable Git SHA"]

        Deploy["Deploy<br/>Azure Container Apps"]

        Test --> Trivy
        Trivy --> Build
        Build --> Push
        Push --> Deploy

    end

    GitHub --> Test

    OIDC["GitHub OIDC<br/>Federated Identity"]
    CIIdentity["Azure Managed Identity<br/>CI/CD Identity"]

    GitHub -->|"OIDC"| OIDC
    OIDC --> CIIdentity

    CIIdentity -->|"Azure authentication"| ACR["Azure Container Registry<br/>vexarfleetdevacr.azurecr.io"]

    Push -->|"Push image"| ACR
    Deploy -->|"Deploy image SHA"| ACA

    subgraph Azure["Azure Cloud"]

        ACA["Azure Container Apps<br/>vexar-fleet-dev-app"]

        API["Fleet Ping API<br/>Node.js 22 / Express<br/>Non-root container"]

        ACA --> API

        RuntimeMI["User Assigned Managed Identity<br/>Runtime Identity"]

        ACA --> RuntimeMI

        RuntimeMI -->|"AcrPull"| ACR

        ACR -->|"Pull container image"| API

        KV["Azure Key Vault<br/>db-password<br/>jwt-secret<br/>demo-otp"]

        RuntimeMI -->|"RBAC / Secret Access"| KV

        KV -->|"Secret references"| API

        subgraph VNet["Azure Virtual Network"]

            PG["Azure Database for PostgreSQL Flexible Server<br/>TLS / SSL"]

            DNS["Private DNS Zone"]

            DNS --> PG

            API -->|"Private Network + TLS"| PG

        end

        LA["Log Analytics<br/>Azure Monitor"]

        API -->|"Logs / Metrics"| LA

        Health["Health / Readiness<br/>/health<br/>/ready"]

        API --> Health

    end

    Client["Fleet Vehicles / API Clients"]

    Client -->|"HTTPS"| ACA