// =============================================================================
// VexarDrive Fleet Ping Service — Input Validation Middleware
// =============================================================================
// Validates request payloads before they reach route handlers.
// Prevents bad data from reaching the database and provides clear error messages.
// =============================================================================

"use strict";

const logger = require("../logger");

/**
 * Validates the fleet ping payload.
 * Required fields: vehicleId, lat, lng, speed, timestamp
 */
function validatePing(req, res, next) {
  const { vehicleId, lat, lng, speed, timestamp } = req.body;
  const errors = [];

  if (!vehicleId || typeof vehicleId !== "string" || vehicleId.trim().length === 0) {
    errors.push("vehicleId is required and must be a non-empty string");
  } else if (vehicleId.length > 50) {
    errors.push("vehicleId must not exceed 50 characters");
  }

  if (lat === undefined || lat === null || typeof lat !== "number" || lat < -90 || lat > 90) {
    errors.push("lat is required and must be a number between -90 and 90");
  }

  if (lng === undefined || lng === null || typeof lng !== "number" || lng < -180 || lng > 180) {
    errors.push("lng is required and must be a number between -180 and 180");
  }

  if (speed === undefined || speed === null || typeof speed !== "number" || speed < 0) {
    errors.push("speed is required and must be a non-negative number");
  }

  if (!timestamp) {
    errors.push("timestamp is required");
  } else {
    const ts = new Date(timestamp);
    if (isNaN(ts.getTime())) {
      errors.push("timestamp must be a valid ISO 8601 date string");
    }
  }

  if (errors.length > 0) {
    logger.warn({ vehicleId, errors }, "Ping validation failed");
    return res.status(400).json({ error: "Validation failed", details: errors });
  }

  next();
}

/**
 * Validates the login payload.
 * Required fields: phone, otp
 */
function validateLogin(req, res, next) {
  const { phone, otp } = req.body;
  const errors = [];

  if (!phone || typeof phone !== "string" || phone.trim().length === 0) {
    errors.push("phone is required and must be a non-empty string");
  } else if (phone.length > 15) {
    errors.push("phone must not exceed 15 characters");
  }

  if (!otp || typeof otp !== "string" || otp.trim().length === 0) {
    errors.push("otp is required and must be a non-empty string");
  }

  if (errors.length > 0) {
    logger.warn({ phone, errors }, "Login validation failed");
    return res.status(400).json({ error: "Validation failed", details: errors });
  }

  next();
}

module.exports = { validatePing, validateLogin };
