// =============================================================================
// VexarDrive Fleet Ping Service — JWT Authentication Middleware
// =============================================================================
// Verifies JWT tokens from the Authorization header.
// Used to protect endpoints that require authentication (e.g., admin routes).
// =============================================================================

"use strict";

const jwt = require("jsonwebtoken");
const config = require("../config");
const logger = require("../logger");

/**
 * Express middleware that verifies JWT Bearer tokens.
 * Attaches decoded payload to `req.user` on success.
 * Returns 401 if token is missing, 403 if token is invalid/expired.
 */
function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    logger.warn({ path: req.path, ip: req.ip }, "Missing or malformed Authorization header");
    return res.status(401).json({ error: "Authentication required" });
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, config.jwt.secret);
    req.user = decoded;
    next();
  } catch (err) {
    logger.warn({ path: req.path, err: err.message }, "Invalid or expired JWT token");

    if (err.name === "TokenExpiredError") {
      return res.status(403).json({ error: "Token expired" });
    }
    return res.status(403).json({ error: "Invalid token" });
  }
}

module.exports = { authenticate };
