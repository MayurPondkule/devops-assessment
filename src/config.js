// =============================================================================
// VexarDrive Fleet Ping Service — Centralized Configuration
// =============================================================================
// All configuration is loaded from environment variables.
// Defaults are provided for local development only.
// In production, all values MUST be set via environment or Key Vault.
// =============================================================================

"use strict";

const config = {
  env: process.env.NODE_ENV || "development",
  port: parseInt(process.env.PORT, 10) || 3000,
  logLevel: process.env.LOG_LEVEL || "info",

  db: {
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || "vexar_fleet",
    ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: true } : false,
    pool: {
      min: parseInt(process.env.DB_POOL_MIN, 10) || 2,
      max: parseInt(process.env.DB_POOL_MAX, 10) || 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    },
  },

  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || "8h",
  },
};

// ---------------------------------------------------------------------------
// Validate required configuration at startup
// ---------------------------------------------------------------------------
const requiredVars = [];

if (!config.db.user) requiredVars.push("DB_USER");
if (!config.db.password) requiredVars.push("DB_PASSWORD");
if (!config.jwt.secret) requiredVars.push("JWT_SECRET");

if (requiredVars.length > 0 && config.env === "production") {
  // In production, fail fast if critical config is missing
  const msg = `Missing required environment variables: ${requiredVars.join(", ")}`;
  console.error(`[FATAL] ${msg}`);
  process.exit(1);
}

// Warn in development if defaults are being used
if (requiredVars.length > 0 && config.env !== "production") {
  console.warn(
    `[WARN] Missing environment variables (using defaults): ${requiredVars.join(", ")}. ` +
    `Copy .env.example to .env and configure.`
  );
  // Apply safe development defaults
  if (!config.db.user) config.db.user = "vexaradmin";
  if (!config.db.password) config.db.password = "localdev";
  if (!config.jwt.secret) config.jwt.secret = "dev-only-not-for-production";
}

module.exports = config;
