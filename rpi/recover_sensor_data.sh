#!/bin/bash

# Recovery script to rebuild SQLite database from CSV backup

WORK_DIR="${WORK_DIR:-/mnt/hdd/plants}"
SENSOR_LOG="$WORK_DIR/sensor_log.csv"
DB_FILE="$WORK_DIR/sensor_data.db"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Recovering SQLite database from sensor_log.csv..."

if [ ! -f "$SENSOR_LOG" ]; then
  echo "Error: sensor_log.csv not found at $SENSOR_LOG"
  exit 1
fi

# Backup existing database if it exists
if [ -f "$DB_FILE" ]; then
  BACKUP="${DB_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
  echo "Backing up existing database to $BACKUP"
  cp "$DB_FILE" "$BACKUP"
fi

# Initialize fresh database
echo "Initializing database..."
sqlite3 "$DB_FILE" < "$SCRIPT_DIR/schema.sql"

# Import CSV data
echo "Importing data from CSV..."
COUNT=0

while IFS=',' read -r timestamp img temp hum; do
  # Skip empty lines
  [ -z "$timestamp" ] && continue

  # Prepare values
  IMG_VALUE="NULL"
  [ -n "$img" ] && [ "$img" != "null" ] && IMG_VALUE="'$img'"

  TEMP_VALUE="NULL"
  [ -n "$temp" ] && [ "$temp" != "null" ] && TEMP_VALUE="$temp"

  HUM_VALUE="NULL"
  [ -n "$hum" ] && [ "$hum" != "null" ] && HUM_VALUE="$hum"

  # Insert into database
  sqlite3 "$DB_FILE" <<EOF
INSERT OR IGNORE INTO sensor_data (timestamp, image_filename, temperature, humidity)
VALUES ('$timestamp', $IMG_VALUE, $TEMP_VALUE, $HUM_VALUE);
EOF

  COUNT=$((COUNT + 1))

  # Progress indicator
  if [ $((COUNT % 100)) -eq 0 ]; then
    echo "Imported $COUNT entries..."
  fi
done < "$SENSOR_LOG"

echo "Imported $COUNT total entries to database"

# Verify
DB_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sensor_data;")
echo "Database now contains $DB_COUNT entries"

echo "Done! Run export_json.sh to update R2."
