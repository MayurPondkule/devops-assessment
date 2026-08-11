## Architecture

###  Architecture

```mermaid
flowchart TB

    Developer["Developer"]

    Developer -->|"Push code"| GitHub["GitHub Repository"]

    subgraph CICD["GitHub Actions CI/CD"]

        Test["Test"]

        Trivy["Trivy Security Scan
        HIGH / CRITICAL gate"]

        Build["Docker Build
        Multi-stage Dockerfile"]

        Push["Push Image
        Immutable Git SHA"]

        Deploy["Deploy
        Azure Container Apps"]

        Test --> Trivy
        Trivy --> Build
        Build --> Push
        Push --> Deploy

    end

    GitHub --> Test

    GitHub -->|"OIDC"| CIIdentity[
        "Azure Managed Identity
        CI/CD Identity"
    ]

    CIIdentity -->|"Azure authentication"| ACR[
        "Azure Container Registry
        vexarfleetdevacr.azurecr.io"
    ]

    Push -->|"Push image"| ACR
    Deploy -->|"Deploy image SHA"| ACA


    subgraph Azure["Azure"]

        ACA[
            "Azure Container Apps
            vexar-fleet-dev-app"
        ]

        API[
            "Fleet Ping API
            Node.js 22 / Express
            Non-root container"
        ]

        ACA --> API


        RuntimeMI[
            "User Assigned Managed Identity
            Runtime Identity"
        ]

        ACA --> RuntimeMI


        RuntimeMI -->|"AcrPull"| ACR

        ACR -->|"Pull container image"| API


        KV[
            "Azure Key Vault"
        ]

        RuntimeMI -->|"RBAC / Secret Access"| KV

        KV -->|"DB Password"| API
        KV -->|"JWT Secret"| API
        KV -->|"Demo OTP"| API


        subgraph VNet["Azure Virtual Network"]

            PG[
                "Azure Database for
                PostgreSQL Flexible Server"
            ]

            DNS[
                "Private DNS Zone"
            ]

            DNS --> PG

            API -->|"Private Network + TLS"| PG

        end


        API -->|"Logs / Metrics"| LA[
            "Log Analytics
            Azure Monitor"
        ]


        Health[
            "Health / Readiness
            /health
            /ready"
        ]

        API --> Health

    end


    Client[
        "Fleet Vehicles /
        API Clients"
    ]

    Client -->|"HTTPS"| ACA