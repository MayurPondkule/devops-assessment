// =============================================================================
// VexarDrive Fleet Ping Service — Health & Readiness Routes
// =============================================================================
// /healthz  — Liveness probe: is the process alive?
// /readyz   — Readiness probe: can the service handle traffic?
//             Checks database connectivity before declaring ready.
// =============================================================================

"use strict";

const express = require("express");
const { isHealthy } = require("../db");
const logger = require("../logger");

const router = express.Router();

/**
 * GET /healthz
 * Liveness probe — returns 200 if the process is running.
 * Used by container orchestrator to determine if the container needs restarting.
 */
router.get("/healthz", (req, res) => {
  res.status(200).json({
    status: "ok",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

/**
 * GET /readyz
 * Readiness probe — returns 200 if the service can handle requests.
 * Checks database connectivity. Returns 503 if the database is unreachable.
 * Used by load balancer to determine if traffic should be routed to this instance.
 */
router.get("/readyz", async (req, res) => {
  const dbHealthy = await isHealthy();

  if (dbHealthy) {
    return res.status(200).json({
      status: "ready",
      timestamp: new Date().toISOString(),
      checks: { database: "ok" },
    });
  }

  logger.error("Readiness check failed — database is unreachable");
  return res.status(503).json({
    status: "not ready",
    timestamp: new Date().toISOString(),
    checks: { database: "failed" },
  });
});

module.exports = router;
