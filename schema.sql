CREATE TABLE IF NOT EXISTS drivers (
    id SERIAL PRIMARY KEY,

    phone VARCHAR(15) UNIQUE NOT NULL,

    name VARCHAR(100),

    role VARCHAR(20) NOT NULL DEFAULT 'driver'
        CHECK (role IN ('driver', 'admin')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS fleet_pings (
    id BIGSERIAL PRIMARY KEY,

    vehicle_id VARCHAR(50) NOT NULL,

    lat DECIMAL(9,6) NOT NULL
        CHECK (lat BETWEEN -90 AND 90),

    lng DECIMAL(9,6) NOT NULL
        CHECK (lng BETWEEN -180 AND 180),

    speed DECIMAL(5,2)
        CHECK (speed >= 0),

    ts TIMESTAMPTZ NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- Useful for retrieving the latest location
-- for a particular vehicle.

CREATE INDEX IF NOT EXISTS idx_fleet_pings_vehicle_ts
ON fleet_pings (vehicle_id, ts DESC);


-- Useful for time-range queries.

CREATE INDEX IF NOT EXISTS idx_fleet_pings_ts
ON fleet_pings (ts DESC);


-- Demo accounts only.
-- Never use real production data here.

INSERT INTO drivers (
    phone,
    name,
    role
)
VALUES (
    '9999999999',
    'Demo Admin',
    'admin'
)
ON CONFLICT (phone) DO NOTHING;


INSERT INTO drivers (
    phone,
    name,
    role
)
VALUES (
    '8888888888',
    'Demo Driver',
    'driver'
)
ON CONFLICT (phone) DO NOTHING;