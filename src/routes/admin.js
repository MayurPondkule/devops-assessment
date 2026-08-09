// =============================================================================
// VexarDrive Fleet Ping Service — Admin Route
// =============================================================================
// GET /api/admin/drivers
// Returns driver list. Now protected with JWT authentication.
// FIXED: Previously had no auth check — any anonymous request could fetch all driver data.
// =============================================================================

"use strict";

const express = require("express");
const { pool } = require("../db");
const logger = require("../logger");
const { authenticate } = require("../middleware/auth");

const router = express.Router();

/**
 * GET /api/admin/drivers
 * Fetches all drivers. Requires valid JWT token.
 *
 * NOTE: In a production system, this should have role-based access control
 * (e.g., only admin users). For now, any authenticated user can access this.
 * This is documented as a future improvement.
 */
router.get("/drivers", authenticate, async (req, res, next) => {
  try {
    // Return only necessary fields (not SELECT *)
    const result = await pool.query(
      "SELECT id, phone, name, created_at FROM drivers ORDER BY created_at DESC"
    );

    logger.info(
      { userId: req.user.driverId, count: result.rows.length },
      "Admin fetched driver list"
    );
    res.json({ drivers: result.rows, count: result.rows.length });
  } catch (err) {
    logger.error({ err }, "Failed to fetch drivers");
    next(err);
  }
});

module.exports = router;
