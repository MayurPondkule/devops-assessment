// =============================================================================
// VexarDrive Fleet Ping Service — Structured Logger
// =============================================================================
// Uses pino for high-performance JSON logging.
// In production: JSON output for Log Analytics / Application Insights ingestion.
// In development: pretty-printed for readability.
// =============================================================================

"use strict";

const pino = require("pino");
const config = require("./config");

const logger = pino({
  level: config.logLevel,

  // Use ISO timestamp for structured log parsing
  timestamp: pino.stdTimeFunctions.isoTime,

  // Base fields included in every log line
  base: {
    service: "fleet-ping-service",
    env: config.env,
  },

  // Pretty-print in development for readability
  transport:
    config.env === "development"
      ? { target: "pino-pretty", options: { colorize: true } }
      : undefined,

  // Redact sensitive fields if they accidentally appear in logs
  redact: {
    paths: ["req.headers.authorization", "password", "token", "secret"],
    censor: "[REDACTED]",
  },
});

module.exports = logger;
