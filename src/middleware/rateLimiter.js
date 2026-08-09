// =============================================================================
// VexarDrive Fleet Ping Service — Rate Limiting Middleware
// =============================================================================
// Application-level rate limiting as defense-in-depth.
// Infrastructure-layer rate limiting (Azure Front Door, API Management)
// should be the primary control. This is a safety net.
// =============================================================================

"use strict";

const logger = require("../logger");

/**
 * Simple in-memory rate limiter using a sliding window.
 * For production at scale, use Redis-backed rate limiting.
 *
 * @param {Object} options
 * @param {number} options.windowMs - Time window in milliseconds
 * @param {number} options.max - Max requests per window per key
 * @param {Function} [options.keyGenerator] - Function to generate rate limit key from req
 */
function rateLimiter({ windowMs = 60000, max = 100, keyGenerator } = {}) {
  const hits = new Map();

  // Clean up expired entries periodically
  const cleanup = setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of hits) {
      if (now - entry.resetTime > windowMs) {
        hits.delete(key);
      }
    }
  }, windowMs);

  // Allow the timer to not prevent process exit
  if (cleanup.unref) cleanup.unref();

  return (req, res, next) => {
    const key = keyGenerator ? keyGenerator(req) : req.ip;
    const now = Date.now();

    let entry = hits.get(key);

    if (!entry || now > entry.resetTime) {
      entry = { count: 0, resetTime: now + windowMs };
      hits.set(key, entry);
    }

    entry.count++;

    // Set rate limit headers
    res.set("X-RateLimit-Limit", String(max));
    res.set("X-RateLimit-Remaining", String(Math.max(0, max - entry.count)));
    res.set("X-RateLimit-Reset", String(Math.ceil(entry.resetTime / 1000)));

    if (entry.count > max) {
      logger.warn({ ip: req.ip, path: req.path }, "Rate limit exceeded");
      return res.status(429).json({
        error: "Too many requests, please try again later",
      });
    }

    next();
  };
}

// --- Pre-configured limiters ---

// Fleet ping limiter: 120 requests/minute per IP
// Fleet devices send pings every 5-30 seconds, so 120/min is generous.
const pingLimiter = rateLimiter({
  windowMs: 60 * 1000,
  max: 120,
});

// Auth limiter: 10 login attempts per 15 minutes per IP
// Prevents brute-force attacks on driver login.
const authLimiter = rateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 10,
});

// General API limiter: 60 requests/minute per IP
const apiLimiter = rateLimiter({
  windowMs: 60 * 1000,
  max: 60,
});

module.exports = { rateLimiter, pingLimiter, authLimiter, apiLimiter };
