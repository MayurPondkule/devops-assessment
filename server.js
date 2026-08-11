const express = require("express");
const helmet = require("helmet");
const jwt = require("jsonwebtoken");
const { Pool } = require("pg");
const { z } = require("zod");

const app = express();

app.disable("x-powered-by");
app.use(helmet());
app.use(express.json({ limit: "32kb" }));

// ------------------------------------------------------------
// Configuration
// ------------------------------------------------------------

const requiredEnv = [
  "DB_HOST",
  "DB_USER",
  "DB_PASSWORD",
  "DB_NAME",
  "JWT_SECRET",
];

for (const name of requiredEnv) {
  if (!process.env[name]) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
}

const config = {
  port: Number(process.env.PORT || 3000),

  nodeEnv: process.env.NODE_ENV || "development",

  db: {
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,

    max: Number(process.env.DB_POOL_MAX || 20),

    idleTimeoutMillis: Number(
      process.env.DB_IDLE_TIMEOUT_MS || 30000
    ),

    connectionTimeoutMillis: Number(
      process.env.DB_CONNECTION_TIMEOUT_MS || 5000
    ),

    ssl:
      process.env.DB_SSL === "true"
        ? {
            rejectUnauthorized:
              process.env.DB_SSL_REJECT_UNAUTHORIZED !== "false",
          }
        : undefined,
  },

  jwtSecret: process.env.JWT_SECRET,

  jwtExpiresIn: process.env.JWT_EXPIRES_IN || "1h",

  // Only for the assessment/local demo.
  // Replace with a real OTP provider in production.
  demoOtp: process.env.DEMO_OTP,
};

// ------------------------------------------------------------
// PostgreSQL connection pool
// ------------------------------------------------------------

const pool = new Pool(config.db);

pool.on("error", (err) => {
  log("error", "db_pool_error", {
    message: err.message,
  });
});

// ------------------------------------------------------------
// Structured logging
// ------------------------------------------------------------

function log(level, event, fields = {}) {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level,
      event,
      ...fields,
    })
  );
}

// ------------------------------------------------------------
// Async route wrapper
// ------------------------------------------------------------

function asyncRoute(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

// ------------------------------------------------------------
// Authentication
// ------------------------------------------------------------

function extractBearerToken(req) {
  const header = req.get("authorization");

  if (!header || !header.startsWith("Bearer ")) {
    return null;
  }

  return header.substring("Bearer ".length);
}

function authenticate(req, res, next) {
  const token = extractBearerToken(req);

  if (!token) {
    return res.status(401).json({
      error: "authentication required",
    });
  }

  try {
    req.user = jwt.verify(token, config.jwtSecret);
    next();
  } catch {
    return res.status(401).json({
      error: "invalid or expired token",
    });
  }
}

function requireAdmin(req, res, next) {
  if (req.user?.role !== "admin") {
    return res.status(403).json({
      error: "admin access required",
    });
  }

  next();
}

// ------------------------------------------------------------
// Validation schemas
// ------------------------------------------------------------

const pingSchema = z.object({
  vehicleId: z.string().trim().min(1).max(50),

  lat: z.number().min(-90).max(90),

  lng: z.number().min(-180).max(180),

  speed: z
    .number()
    .min(0)
    .max(500)
    .optional()
    .nullable(),

  timestamp: z
    .string()
    .datetime({ offset: true })
    .optional(),
});

const loginSchema = z.object({
  phone: z.string().trim().min(5).max(15),

  otp: z.string().trim().min(4).max(10),
});

// ------------------------------------------------------------
// Health endpoint
// ------------------------------------------------------------

app.get("/health", (_req, res) => {
  res.status(200).json({
    status: "ok",
  });
});

// ------------------------------------------------------------
// Readiness endpoint
// ------------------------------------------------------------

app.get(
  "/ready",
  asyncRoute(async (_req, res) => {
    await pool.query("SELECT 1");

    res.status(200).json({
      status: "ready",
    });
  })
);

// ------------------------------------------------------------
// Root
// ------------------------------------------------------------

app.get("/", (_req, res) => {
  res.json({
    service: "vexar-fleet-ping-service",
    status: "running",
  });
});

// ------------------------------------------------------------
// Fleet ping ingestion
// ------------------------------------------------------------

app.post(
  "/api/fleet/ping",
  asyncRoute(async (req, res) => {
    const parsed = pingSchema.safeParse(req.body);

    if (!parsed.success) {
      return res.status(400).json({
        error: "invalid request",
        details: parsed.error.flatten().fieldErrors,
      });
    }

    const {
      vehicleId,
      lat,
      lng,
      speed,
      timestamp,
    } = parsed.data;

    const pingTimestamp = timestamp
      ? new Date(timestamp)
      : new Date();

    await pool.query(
      `
      INSERT INTO fleet_pings
        (vehicle_id, lat, lng, speed, ts)
      VALUES
        ($1, $2, $3, $4, $5)
      `,
      [
        vehicleId,
        lat,
        lng,
        speed ?? null,
        pingTimestamp,
      ]
    );

    res.status(201).json({
      status: "ok",
    });
  })
);

// ------------------------------------------------------------
// Driver login
// ------------------------------------------------------------

app.post(
  "/api/auth/login",
  asyncRoute(async (req, res) => {
    const parsed = loginSchema.safeParse(req.body);

    if (!parsed.success) {
      return res.status(400).json({
        error: "invalid request",
        details: parsed.error.flatten().fieldErrors,
      });
    }

    const {
      phone,
      otp,
    } = parsed.data;

    /*
     * The starter repository does not provide an OTP service.
     *
     * For the assessment we use DEMO_OTP only to demonstrate
     * the authentication flow.
     *
     * Production implementation should integrate with a
     * real OTP provider.
     */

    if (!config.demoOtp || otp !== config.demoOtp) {
      return res.status(401).json({
        error: "invalid credentials",
      });
    }

    /*
     * Parameterized query prevents SQL injection.
     */

    const result = await pool.query(
      `
      SELECT
        id,
        phone,
        name,
        role
      FROM drivers
      WHERE phone = $1
      `,
      [phone]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        error: "invalid credentials",
      });
    }

    const driver = result.rows[0];

    const token = jwt.sign(
      {
        sub: String(driver.id),
        driverId: driver.id,
        role: driver.role,
      },
      config.jwtSecret,
      {
        expiresIn: config.jwtExpiresIn,
      }
    );

    res.json({
      token,
    });
  })
);

// ------------------------------------------------------------
// Admin endpoint
// ------------------------------------------------------------

app.get(
  "/api/admin/drivers",
  authenticate,
  requireAdmin,
  asyncRoute(async (_req, res) => {
    const result = await pool.query(
      `
      SELECT
        id,
        phone,
        name,
        role,
        created_at
      FROM drivers
      ORDER BY id
      `
    );

    res.json(result.rows);
  })
);

// ------------------------------------------------------------
// 404 handler
// ------------------------------------------------------------

app.use((req, res) => {
  res.status(404).json({
    error: "route not found",
  });
});

// ------------------------------------------------------------
// Global error handler
// ------------------------------------------------------------

app.use((err, req, res, _next) => {
  log("error", "request_failed", {
    method: req.method,
    path: req.path,
    message: err.message,
  });

  res.status(500).json({
    error: "internal server error",
  });
});

// ------------------------------------------------------------
// Server
// ------------------------------------------------------------

let server = null;

if (require.main === module) {
  server = app.listen(config.port, () => {
    log("info", "server_started", {
      port: config.port,
      environment: config.nodeEnv,
    });
  });
}

// ------------------------------------------------------------
// Graceful shutdown
// ------------------------------------------------------------

async function shutdown(signal) {
  log("info", "shutdown_started", {
    signal,
  });

  if (!server) {
  await pool.end();
  return;
}

server.close(async () => {
    try {
      await pool.end();

      log("info", "shutdown_completed");

      process.exit(0);
    } catch (err) {
      log("error", "shutdown_failed", {
        message: err.message,
      });

      process.exit(1);
    }
  });

  setTimeout(() => {
    log("error", "shutdown_timeout");

    process.exit(1);
  }, 10000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

module.exports = {
  app,
  pool,
  server,
};