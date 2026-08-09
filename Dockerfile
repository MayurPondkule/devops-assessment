# =============================================================================
# VexarDrive Fleet Ping Service — Production Dockerfile
# =============================================================================
# Multi-stage build for minimal, secure production images.
#
# Key decisions:
#   - node:22-alpine: Pinned version, Alpine-based (~50MB vs ~1GB for node:latest)
#   - Multi-stage: Builder stage installs deps, runtime stage copies only production artifacts
#   - Non-root user: Runs as 'node' (UID 1000) — defense in depth
#   - npm ci --omit=dev: Deterministic installs, no devDependencies in production
#   - dumb-init: Proper PID 1 signal forwarding for graceful shutdown
#   - HEALTHCHECK: Built-in container health monitoring
#   - No EXPOSE 22: Removed unnecessary SSH port from original
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Builder — install dependencies
# ---------------------------------------------------------------------------
FROM node:22-alpine3.20 AS builder

WORKDIR /app

# Copy package files first for Docker layer caching.
# If package.json hasn't changed, npm ci is skipped on rebuild.
COPY package.json package-lock.json* ./

# Install ALL dependencies (including dev) for potential build steps.
# Using npm ci for deterministic, reproducible installs from lockfile.
RUN npm ci

# Copy application source
COPY server.js ./
COPY src/ ./src/

# ---------------------------------------------------------------------------
# Stage 2: Runtime — lean production image
# ---------------------------------------------------------------------------
FROM node:22-alpine3.20 AS runtime

# Install dumb-init for proper PID 1 signal handling.
# Without this, Node.js doesn't receive SIGTERM properly in containers,
# preventing graceful shutdown (connection draining, cleanup).
RUN apk add --no-cache dumb-init

# Set production environment
ENV NODE_ENV=production

WORKDIR /app

# Copy only production dependencies from builder
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy application source from builder
COPY --from=builder /app/server.js ./
COPY --from=builder /app/src/ ./src/

# Use non-root user for security.
# The 'node' user is created by the node:alpine base image.
USER node

# Application port only — no SSH (removed EXPOSE 22 from original)
EXPOSE 3000

# Container health check — used by Docker and orchestrators
# Checks the /healthz endpoint every 30 seconds.
# Allows 5s for the app to start, retries 3 times before marking unhealthy.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/healthz || exit 1

# Use dumb-init as entrypoint for proper signal forwarding
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "server.js"]
