// =============================================================================
// VexarDrive — Fleet Ping Service
// =============================================================================
// Production-ready Node.js/Express backend for receiving vehicle location pings,
// handling driver authentication, and managing fleet data.
//
// Originally inherited as legacy code with hardcoded credentials, SQL injection
// vulnerabilities, no connection pooling, and missing security controls.
//
// Refactored for production readiness. See docs/TECHNICAL_REPORT.md for details.
// =============================================================================

"use strict";

const express = require("express");
const helmet = require("helmet");
const pinoHttp = require("pino-http");

const config = require("./src/config");
const logger = require("./src/logger");
const { shutdown: dbShutdown } = require("./src/db");

// Routes
const healthRoutes = require("./src/routes/health");
const fleetRoutes = require("./src/routes/fleet");
const authRoutes = require("./src/routes/auth");
const adminRoutes = require("./src/routes/admin");

// Error handling
const { errorHandler, notFoundHandler } = require("./src/middleware/errorHandler");

// Rate limiting (defense-in-depth — infrastructure layer is primary control)
const { pingLimiter, authLimiter, apiLimiter } = require("./src/middleware/rateLimiter");

// =============================================================================
// Express App Setup
// =============================================================================
const app = express();

// --- Security Headers ---
// helmet sets various HTTP headers to protect against common attacks
// (XSS, clickjacking, MIME sniffing, etc.)
app.use(helmet());

// --- Request Parsing ---
app.use(express.json({ limit: "1mb" }));

// --- Request Logging ---
// Structured HTTP request/response logging for every request
app.use(
  pinoHttp({
    logger,
    // Don't log health check requests (noisy in production)
    autoLogging: {
      ignore: (req) => req.url === "/healthz",
    },
    // Custom serializers for log output
    customLogLevel: (req, res, err) => {
      if (res.statusCode >= 500 || err) return "error";
      if (res.statusCode >= 400) return "warn";
      return "info";
    },
  })
);

// --- Routes ---
app.get("/", (req, res) => {
  res.json({
    service: "VexarDrive Fleet Ping Service",
    version: process.env.npm_package_version || "0.1.0",
    status: "running",
  });
});

app.use(healthRoutes);
app.use("/api/fleet", pingLimiter, fleetRoutes);
app.use("/api/auth", authLimiter, authRoutes);
app.use("/api/admin", apiLimiter, adminRoutes);

// --- Error Handling (must be after routes) ---
app.use(notFoundHandler);
app.use(errorHandler);

// =============================================================================
// Server Start & Graceful Shutdown
// =============================================================================
let server;

function startServer() {
  server = app.listen(config.port, () => {
    logger.info(
      { port: config.port, env: config.env },
      `Fleet Ping Service started on port ${config.port}`
    );
  });

  // Configure keep-alive and header timeouts for production
  server.keepAliveTimeout = 65000; // Slightly higher than ALB/ingress idle timeout
  server.headersTimeout = 66000;

  return server;
}

// ---------------------------------------------------------------------------
// Graceful Shutdown
// ---------------------------------------------------------------------------
// On SIGTERM/SIGINT: stop accepting new connections, finish in-flight requests,
// drain the database pool, then exit cleanly.
// This prevents data loss during deployments and container restarts.
// ---------------------------------------------------------------------------
async function gracefulShutdown(signal) {
  logger.info({ signal }, "Received shutdown signal, starting graceful shutdown...");

  // Stop accepting new connections
  if (server) {
    server.close(async () => {
      logger.info("HTTP server closed — no more incoming connections");

      try {
        // Drain database connections
        await dbShutdown();
        logger.info("Graceful shutdown complete");
        process.exit(0);
      } catch (err) {
        logger.error({ err }, "Error during database shutdown");
        process.exit(1);
      }
    });

    // Force shutdown after 30 seconds if graceful shutdown hangs
    setTimeout(() => {
      logger.error("Graceful shutdown timed out — forcing exit");
      process.exit(1);
    }, 30000);
  } else {
    process.exit(0);
  }
}

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));

// Handle unhandled rejections and uncaught exceptions
process.on("unhandledRejection", (reason, promise) => {
  logger.error({ reason, promise: String(promise) }, "Unhandled promise rejection");
});

process.on("uncaughtException", (err) => {
  logger.fatal({ err }, "Uncaught exception — shutting down");
  process.exit(1);
});

// =============================================================================
// Start the server (only when run directly, not when imported for testing)
// =============================================================================
if (require.main === module) {
  startServer();
}

// Export app for testing
module.exports = app;
