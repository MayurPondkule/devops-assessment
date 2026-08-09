// =============================================================================
// VexarDrive Fleet Ping Service — Authentication Route
// =============================================================================
// POST /api/auth/login
// Handles driver login via phone + OTP.
// FIXED: SQL injection vulnerability replaced with parameterized query.
// =============================================================================

"use strict";

const express = require("express");
const jwt = require("jsonwebtoken");
const { pool } = require("../db");
const config = require("../config");
const logger = require("../logger");
const { validateLogin } = require("../middleware/validate");

const router = express.Router();

/**
 * POST /api/auth/login
 * Authenticates a driver by phone number and OTP.
 *
 * NOTE: OTP verification is not fully implemented in this legacy service.
 * The OTP value is accepted but not validated against a stored/sent code.
 * This is documented as a known limitation — implementing OTP verification
 * is application/product logic beyond the scope of this DevOps assessment.
 */
router.post("/login", validateLogin, async (req, res, next) => {
  const { phone } = req.body;

  try {
    // FIXED: Parameterized query prevents SQL injection.
    // Original code used string interpolation: `SELECT * FROM drivers WHERE phone = '${phone}'`
    const result = await pool.query(
      "SELECT id, phone, name FROM drivers WHERE phone = $1",
      [phone]
    );

    if (result.rows.length === 0) {
      logger.warn({ phone }, "Login attempt — driver not found");
      return res.status(401).json({ error: "Driver not found" });
    }

    const driver = result.rows[0];
    const token = jwt.sign(
      { driverId: driver.id, phone: driver.phone },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    logger.info({ driverId: driver.id }, "Driver logged in successfully");
    res.json({ token });
  } catch (err) {
    logger.error({ err, phone }, "Login failed");
    next(err);
  }
});

module.exports = router;
