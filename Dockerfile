# syntax=docker/dockerfile:1

# ------------------------------------------------------------
# Dependency stage
# ------------------------------------------------------------

FROM node:22-alpine AS dependencies

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev \
    --no-audit \
    --no-fund \
    && npm cache clean --force


# ------------------------------------------------------------
# Runtime stage
# ------------------------------------------------------------

FROM node:22-alpine AS runtime

ENV NODE_ENV=production
ENV PORT=3000

WORKDIR /app


# Remove package managers from the runtime image.
# npm is required only during the dependency/build stage.
RUN rm -rf /usr/local/lib/node_modules/npm \
    /usr/local/bin/npm \
    /usr/local/bin/npx


# Create non-root user

RUN addgroup -S appgroup \
    && adduser -S appuser -G appgroup


# Copy production dependencies

COPY --from=dependencies /app/node_modules ./node_modules


# Copy application

COPY package*.json ./
COPY server.js ./
COPY schema.sql ./


# Run as non-root

USER appuser


EXPOSE 3000


# Container health check

HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=10s \
    --retries=3 \
    CMD node -e "\
      require('http') \
        .get('http://127.0.0.1:3000/health', r => \
          process.exit(r.statusCode === 200 ? 0 : 1)) \
        .on('error', () => process.exit(1))"


CMD ["node", "server.js"]