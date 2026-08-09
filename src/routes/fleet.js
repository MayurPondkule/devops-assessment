// =============================================================================
// VexarDrive Fleet Ping Service — Fleet Ping Ingestion Route
// =============================================================================
// POST /api/fleet/ping
// Receives high-frequency vehicle location updates from fleet devices.
// Uses connection pool instead of per-request connections.
// =============================================================================

"use strict";

const express = require("express");
const { pool } = require("../db");
const logger = require("../logger");
const { validatePing } = require("../middleware/validate");

const router = express.Router();

/**
 * POST /api/fleet/ping
 * Ingests a vehicle location ping.
 * Called very frequently by field devices — performance is critical.
 */
router.post("/ping", validatePing, async (req, res, next) => {
  const { vehicleId, lat, lng, speed, timestamp } = req.body;

  try {
    await pool.query(
      `INSERT INTO fleet_pings (vehicle_id, lat, lng, speed, ts) VALUES ($1, $2, $3, $4, $5)`,
      [vehicleId, lat, lng, speed, timestamp]
    );

    logger.info({ vehicleId, lat, lng, speed }, "Fleet ping ingested");
    res.status(201).json({ status: "ok" });
  } catch (err) {
    logger.error({ err, vehicleId }, "Failed to insert fleet ping");
    next(err);
  }
});

module.exports = router;
