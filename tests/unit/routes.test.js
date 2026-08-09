// =============================================================================
// VexarDrive Fleet Ping Service — Unit Tests
// =============================================================================

"use strict";

const request = require("supertest");
const express = require("express");

// ---------------------------------------------------------------------------
// Mock dependencies before requiring routes
// ---------------------------------------------------------------------------
jest.mock("../../src/db", () => ({
  pool: {
    query: jest.fn(),
  },
  isHealthy: jest.fn(),
  shutdown: jest.fn(),
}));

jest.mock("../../src/logger", () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
  trace: jest.fn(),
  fatal: jest.fn(),
  child: jest.fn(() => ({
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  })),
}));

const { pool, isHealthy } = require("../../src/db");
const healthRoutes = require("../../src/routes/health");
const fleetRoutes = require("../../src/routes/fleet");
const authRoutes = require("../../src/routes/auth");

// ---------------------------------------------------------------------------
// Helper: create a minimal Express app with routes
// ---------------------------------------------------------------------------
function createApp(routes, prefix = "") {
  const app = express();
  app.use(express.json());
  if (prefix) {
    app.use(prefix, routes);
  } else {
    app.use(routes);
  }
  // Add error handler
  app.use((err, req, res, _next) => {
    res.status(500).json({ error: err.message });
  });
  return app;
}

// =============================================================================
// Health Routes
// =============================================================================
describe("Health Routes", () => {
  describe("GET /healthz", () => {
    it("should return 200 with status ok", async () => {
      const app = createApp(healthRoutes);
      const res = await request(app).get("/healthz");

      expect(res.status).toBe(200);
      expect(res.body.status).toBe("ok");
      expect(res.body).toHaveProperty("timestamp");
      expect(res.body).toHaveProperty("uptime");
    });
  });

  describe("GET /readyz", () => {
    it("should return 200 when database is healthy", async () => {
      isHealthy.mockResolvedValue(true);
      const app = createApp(healthRoutes);
      const res = await request(app).get("/readyz");

      expect(res.status).toBe(200);
      expect(res.body.status).toBe("ready");
      expect(res.body.checks.database).toBe("ok");
    });

    it("should return 503 when database is unhealthy", async () => {
      isHealthy.mockResolvedValue(false);
      const app = createApp(healthRoutes);
      const res = await request(app).get("/readyz");

      expect(res.status).toBe(503);
      expect(res.body.status).toBe("not ready");
      expect(res.body.checks.database).toBe("failed");
    });
  });
});

// =============================================================================
// Fleet Routes
// =============================================================================
describe("Fleet Routes", () => {
  describe("POST /ping", () => {
    const validPing = {
      vehicleId: "VEX-001",
      lat: 28.6139,
      lng: 77.2090,
      speed: 45.5,
      timestamp: "2024-01-15T10:30:00Z",
    };

    it("should return 201 on valid ping", async () => {
      pool.query.mockResolvedValue({ rows: [] });
      const app = createApp(fleetRoutes, "/api/fleet");
      const res = await request(app)
        .post("/api/fleet/ping")
        .send(validPing);

      expect(res.status).toBe(201);
      expect(res.body.status).toBe("ok");
      expect(pool.query).toHaveBeenCalledWith(
        expect.stringContaining("INSERT INTO fleet_pings"),
        [validPing.vehicleId, validPing.lat, validPing.lng, validPing.speed, validPing.timestamp]
      );
    });

    it("should return 400 on missing vehicleId", async () => {
      const app = createApp(fleetRoutes, "/api/fleet");
      const res = await request(app)
        .post("/api/fleet/ping")
        .send({ ...validPing, vehicleId: undefined });

      expect(res.status).toBe(400);
      expect(res.body.error).toBe("Validation failed");
    });

    it("should return 400 on invalid latitude", async () => {
      const app = createApp(fleetRoutes, "/api/fleet");
      const res = await request(app)
        .post("/api/fleet/ping")
        .send({ ...validPing, lat: 100 });

      expect(res.status).toBe(400);
    });

    it("should return 400 on invalid longitude", async () => {
      const app = createApp(fleetRoutes, "/api/fleet");
      const res = await request(app)
        .post("/api/fleet/ping")
        .send({ ...validPing, lng: -200 });

      expect(res.status).toBe(400);
    });

    it("should return 400 on negative speed", async () => {
      const app = createApp(fleetRoutes, "/api/fleet");
      const res = await request(app)
        .post("/api/fleet/ping")
        .send({ ...validPing, speed: -10 });

      expect(res.status).toBe(400);
    });

    it("should return 400 on invalid timestamp", async () => {
      const app = createApp(fleetRoutes, "/api/fleet");
      const res = await request(app)
        .post("/api/fleet/ping")
        .send({ ...validPing, timestamp: "not-a-date" });

      expect(res.status).toBe(400);
    });

    it("should return 500 on database error", async () => {
      pool.query.mockRejectedValue(new Error("Connection refused"));
      const app = createApp(fleetRoutes, "/api/fleet");
      const res = await request(app)
        .post("/api/fleet/ping")
        .send(validPing);

      expect(res.status).toBe(500);
    });
  });
});

// =============================================================================
// Auth Routes
// =============================================================================
describe("Auth Routes", () => {
  describe("POST /login", () => {
    it("should return token on valid login", async () => {
      pool.query.mockResolvedValue({
        rows: [{ id: 1, phone: "+919876543210", name: "Test Driver" }],
      });

      const app = createApp(authRoutes, "/api/auth");
      const res = await request(app)
        .post("/api/auth/login")
        .send({ phone: "+919876543210", otp: "123456" });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty("token");
    });

    it("should return 401 on unknown phone number", async () => {
      pool.query.mockResolvedValue({ rows: [] });

      const app = createApp(authRoutes, "/api/auth");
      const res = await request(app)
        .post("/api/auth/login")
        .send({ phone: "+910000000000", otp: "123456" });

      expect(res.status).toBe(401);
    });

    it("should return 400 on missing phone", async () => {
      const app = createApp(authRoutes, "/api/auth");
      const res = await request(app)
        .post("/api/auth/login")
        .send({ otp: "123456" });

      expect(res.status).toBe(400);
    });

    it("should return 400 on missing otp", async () => {
      const app = createApp(authRoutes, "/api/auth");
      const res = await request(app)
        .post("/api/auth/login")
        .send({ phone: "+919876543210" });

      expect(res.status).toBe(400);
    });

    it("should use parameterized query (no SQL injection)", async () => {
      pool.query.mockClear();
      pool.query.mockResolvedValue({ rows: [] });

      const app = createApp(authRoutes, "/api/auth");
      // Use a string that passes validation (<=15 chars) but contains SQL chars
      const maliciousPhone = "1' OR '1'='1";
      await request(app)
        .post("/api/auth/login")
        .send({ phone: maliciousPhone, otp: "123456" });

      // Verify parameterized query was used (not string interpolation)
      expect(pool.query).toHaveBeenLastCalledWith(
        expect.stringContaining("$1"),
        [maliciousPhone]
      );
    });
  });
});
