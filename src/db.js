// =============================================================================
// VexarDrive Fleet Ping Service — Database Connection Pool
// =============================================================================
// Uses pg.Pool instead of creating a new Client per request.
// Pool maintains persistent connections, handles reconnection, and prevents
// connection exhaustion under high-frequency fleet ping traffic.
// =============================================================================

"use strict";

const { Pool } = require("pg");
const config = require("./config");
const logger = require("./logger");

const pool = new Pool({
  host: config.db.host,
  port: config.db.port,
  user: config.db.user,
  password: config.db.password,
  database: config.db.database,
  ssl: config.db.ssl,
  min: config.db.pool.min,
  max: config.db.pool.max,
  idleTimeoutMillis: config.db.pool.idleTimeoutMillis,
  connectionTimeoutMillis: config.db.pool.connectionTimeoutMillis,
});

// ---------------------------------------------------------------------------
// Pool event logging — critical for monitoring connection health
// ---------------------------------------------------------------------------
pool.on("connect", () => {
  logger.debug("New database connection established");
});

pool.on("acquire", () => {
  logger.trace("Client acquired from pool");
});

pool.on("remove", () => {
  logger.debug("Client removed from pool");
});

pool.on("error", (err) => {
  logger.error({ err }, "Unexpected database pool error");
});

// ---------------------------------------------------------------------------
// Health check — used by /readyz endpoint
// ---------------------------------------------------------------------------
async function isHealthy() {
  try {
    const result = await pool.query("SELECT 1 AS ok");
    return result.rows[0]?.ok === 1;
  } catch (err) {
    logger.error({ err }, "Database health check failed");
    return false;
  }
}

// ---------------------------------------------------------------------------
// Graceful shutdown — drain all connections
// ---------------------------------------------------------------------------
async function shutdown() {
  logger.info("Draining database connection pool...");
  await pool.end();
  logger.info("Database connection pool closed");
}

module.exports = { pool, isHealthy, shutdown };
