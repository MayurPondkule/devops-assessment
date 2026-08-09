-- =============================================================================
-- VexarDrive Fleet Ping Service — Initial Schema
-- Migration: 001_initial_schema.sql
-- =============================================================================
-- Creates the core tables for the fleet ping service.
-- Applied automatically on first Docker Compose startup.
-- =============================================================================

-- Drivers table — stores fleet driver information
CREATE TABLE IF NOT EXISTS drivers (
  id SERIAL PRIMARY KEY,
  phone VARCHAR(15) UNIQUE NOT NULL,
  name VARCHAR(100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Fleet pings table — stores vehicle location updates
-- Using BIGSERIAL instead of SERIAL to handle high-volume ping data.
-- SERIAL (int4) maxes out at ~2.1 billion rows — for a fleet service sending
-- pings every few seconds, this could be reached within months.
CREATE TABLE IF NOT EXISTS fleet_pings (
  id BIGSERIAL PRIMARY KEY,
  vehicle_id VARCHAR(50) NOT NULL,
  lat DECIMAL(9,6),
  lng DECIMAL(9,6),
  speed DECIMAL(5,2),
  ts TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Note: Indexes are added in 002_add_indexes.sql
