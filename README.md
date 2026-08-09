# Fleet Ping Service — VexarDrive Technologies

Production-ready Node.js/Express backend service for receiving vehicle location pings, handling driver authentication, and managing fleet data on Azure.

> **Assessment Context**: This repository is a refactored and production-hardened version of the starter repository provided for the VexarDrive DevOps & Cloud Infrastructure Engineer Technical Assessment.

## Documentation

| Document | Description |
|----------|-------------|
| [Technical Report](docs/TECHNICAL_REPORT.md) | Full engineering report — decisions, trade-offs, rationale |
| [Architecture Diagram](docs/ARCHITECTURE_DIAGRAM.md) | Azure infrastructure diagrams (Mermaid) |
| [Database Operations](docs/DATABASE_OPERATIONS.md) | Backup, recovery, scaling, access control |

## Technology Stack

- **Runtime**: Node.js 22, Express.js
- **Database**: PostgreSQL 16 (Azure Database for PostgreSQL Flexible Server)
- **Container**: Docker (multi-stage, Alpine-based)
- **Infrastructure**: Terraform (Azure)
- **CI/CD**: GitHub Actions
- **Monitoring**: Azure Log Analytics, Application Insights
- **Secrets**: Azure Key Vault + Managed Identity

## Repository Structure

```
.
├── .github/workflows/
│   ├── ci.yml                 # Test → Build → Scan → Push
│   └── deploy.yml             # Staging → Approval → Prod (canary)
├── src/
│   ├── config.js              # Centralized env-based configuration
│   ├── db.js                  # PostgreSQL connection pool
│   ├── logger.js              # Structured logging (pino)
│   ├── middleware/
│   │   ├── auth.js            # JWT authentication
│   │   ├── validate.js        # Input validation
│   │   ├── rateLimiter.js     # Rate limiting (defense-in-depth)
│   │   └── errorHandler.js    # Global error handler
│   └── routes/
│       ├── health.js          # /healthz, /readyz
│       ├── fleet.js           # POST /api/fleet/ping
│       ├── auth.js            # POST /api/auth/login
│       └── admin.js           # GET /api/admin/drivers
├── tests/
│   └── unit/
│       └── routes.test.js     # 15 unit tests
├── db/migrations/
│   ├── 001_initial_schema.sql
│   └── 002_add_indexes.sql
├── terraform/
│   ├── main.tf                # Module orchestration
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── modules/
│   │   ├── networking/        # VNet, subnets, NSGs, private DNS
│   │   ├── database/          # PostgreSQL Flexible Server
│   │   ├── keyvault/          # Key Vault + secrets
│   │   ├── container_apps/    # Container Apps + autoscaling
│   │   ├── identity/          # Managed Identity + RBAC
│   │   └── monitoring/        # Log Analytics + App Insights + Alerts
│   └── environments/
│       ├── dev.tfvars
│       ├── staging.tfvars
│       └── prod.tfvars
├── docs/
│   ├── TECHNICAL_REPORT.md
│   ├── ARCHITECTURE_DIAGRAM.md
│   └── DATABASE_OPERATIONS.md
├── Dockerfile                 # Multi-stage production build
├── docker-compose.yml         # Local development only
├── .dockerignore
├── .gitignore
├── .env.example
├── eslint.config.js           # ESLint code quality config
├── package.json
├── schema.sql                 # Original schema (preserved for reference)
└── server.js                  # Application entrypoint
```

## Quick Start (Local Development)

### Prerequisites

- Node.js >= 22
- Docker & Docker Compose

### Setup

```bash
# Clone the repository
git clone https://github.com/MayurPondkule/devops-assessment.git
cd devops-assessment

# Configure environment
cp .env.example .env
# Edit .env with your local settings

# Start with Docker Compose
docker compose up --build

# Or run natively
npm install
npm run dev
```

### Run Tests

```bash
npm test              # All tests
npm run test:unit     # Unit tests only
npm run test:coverage # With coverage report
```

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/` | No | Service info |
| `GET` | `/healthz` | No | Liveness probe |
| `GET` | `/readyz` | No | Readiness probe (checks DB) |
| `POST` | `/api/fleet/ping` | No | Ingest vehicle location ping |
| `POST` | `/api/auth/login` | No | Driver login (phone + OTP) |
| `GET` | `/api/admin/drivers` | JWT | List all drivers |

### Example: Send a Fleet Ping

```bash
curl -X POST http://localhost:3000/api/fleet/ping \
  -H "Content-Type: application/json" \
  -d '{
    "vehicleId": "VEX-001",
    "lat": 18.5204,
    "lng": 73.8567,
    "speed": 45.5,
    "timestamp": "2024-01-15T10:30:00Z"
  }'
```

## Key Improvements Over Starter Repo

1. **🔐 Security**: Removed hardcoded credentials, fixed SQL injection, added JWT auth on admin endpoint
2. **⚡ Performance**: Connection pooling (replaces per-request connections)
3. **🛡️ Rate Limiting**: Per-IP rate limits on ping (120/min), auth (10/15min), admin (60/min) endpoints
4. **🐳 Container**: Multi-stage Alpine build (~50MB vs ~1GB), non-root user, health checks
5. **🏗️ Infrastructure**: Full Terraform IaC with 6 modular components for Azure
6. **🚀 CI/CD**: Complete pipeline with security scanning, canary deployments, rollback
7. **📊 Observability**: Structured logging, health/readiness probes, alert rules
8. **✅ Testing**: 15 unit tests including SQL injection prevention verification

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NODE_ENV` | No | `development` | Environment mode |
| `PORT` | No | `3000` | HTTP server port |
| `DB_HOST` | Yes (prod) | `localhost` | PostgreSQL host |
| `DB_PORT` | No | `5432` | PostgreSQL port |
| `DB_USER` | Yes (prod) | — | Database username |
| `DB_PASSWORD` | Yes (prod) | — | Database password |
| `DB_NAME` | No | `vexar_fleet` | Database name |
| `DB_SSL` | No | `false` | Enable SSL for DB connection |
| `DB_POOL_MIN` | No | `2` | Min pool connections |
| `DB_POOL_MAX` | No | `10` | Max pool connections |
| `JWT_SECRET` | Yes (prod) | — | JWT signing secret |
| `JWT_EXPIRES_IN` | No | `8h` | JWT token expiry |
| `LOG_LEVEL` | No | `info` | Logging level |