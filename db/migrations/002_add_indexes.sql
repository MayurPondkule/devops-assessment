-- =============================================================================
-- VexarDrive Fleet Ping Service — Add Indexes
-- Migration: 002_add_indexes.sql
-- =============================================================================
-- Performance indexes for the fleet ping service.
-- Critical for query performance as data volume grows.
-- =============================================================================

-- Index on fleet_pings.vehicle_id — used for filtering pings by vehicle
-- Without this, queries like "get all pings for vehicle X" do a full table scan.
CREATE INDEX IF NOT EXISTS idx_fleet_pings_vehicle_id
  ON fleet_pings (vehicle_id);

-- Composite index on fleet_pings (vehicle_id, ts) — used for time-range queries
-- e.g., "get pings for vehicle X in the last hour"
CREATE INDEX IF NOT EXISTS idx_fleet_pings_vehicle_ts
  ON fleet_pings (vehicle_id, ts DESC);

-- Index on fleet_pings.created_at — useful for data retention/cleanup queries
CREATE INDEX IF NOT EXISTS idx_fleet_pings_created_at
  ON fleet_pings (created_at);

-- Index on drivers.phone — used for login lookups
-- (phone already has a UNIQUE constraint which creates an index,
-- but this is here for documentation clarity)
