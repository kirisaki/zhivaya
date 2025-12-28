-- SQLite schema for sensor data

CREATE TABLE IF NOT EXISTS sensor_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL UNIQUE,  -- Format: YYYYMMDD_HHMMSS
    image_filename TEXT,              -- NULL for nighttime entries
    temperature REAL,                 -- Celsius, NULL if sensor failed
    humidity REAL,                    -- Percentage, NULL if sensor failed
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster queries by timestamp
CREATE INDEX IF NOT EXISTS idx_timestamp ON sensor_data(timestamp DESC);

-- Index for filtering entries with images
CREATE INDEX IF NOT EXISTS idx_image_filename ON sensor_data(image_filename) WHERE image_filename IS NOT NULL;
