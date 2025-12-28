#!/bin/bash

# Recovery script to rebuild sensor_data.json from R2 image files and local CSV

WORK_DIR="${WORK_DIR:-/mnt/hdd/plants}"
R2_REMOTE="zhivaya:zhivaya"
RCLONE_CONF="$HOME/.config/rclone/rclone.conf"
SENSOR_LOG="$WORK_DIR/sensor_log.csv"
SENSOR_JSON="sensor_data.json"

echo "Recovering sensor_data.json from R2 image files..."

# Get all img_*.jpg files from R2
echo "Fetching image list from R2..."
IMAGE_LIST=$(rclone lsjson "$R2_REMOTE" --config "$RCLONE_CONF" | \
  jq -r '[.[] | select(.Name | test("^img_.*\\.jpg$")) | .Name] | sort | .[]')

# Check if sensor_log.csv exists
if [ -f "$SENSOR_LOG" ]; then
  echo "Found sensor_log.csv, will recover temp/hum data"
  USE_CSV=true
else
  echo "No sensor_log.csv found, temp/hum will be null"
  USE_CSV=false
fi

# Build JSON array
echo "[" > "$SENSOR_JSON"
FIRST=true

for img in $IMAGE_LIST; do
  # Extract timestamp from filename (img_YYYYMMDD_HHMMSS.jpg)
  TIME=$(echo "$img" | sed 's/^img_//' | sed 's/\.jpg$//')

  # Default values
  TEMP="null"
  HUM="null"

  # Try to find matching entry in CSV
  if [ "$USE_CSV" = true ]; then
    CSV_LINE=$(grep "^${TIME}," "$SENSOR_LOG" 2>/dev/null)
    if [ -n "$CSV_LINE" ]; then
      # Parse CSV: time,img,temp,hum
      TEMP=$(echo "$CSV_LINE" | cut -d',' -f3)
      HUM=$(echo "$CSV_LINE" | cut -d',' -f4)

      # Convert "null" string to actual null
      [ "$TEMP" = "null" ] && TEMP="null" || TEMP="$TEMP"
      [ "$HUM" = "null" ] && HUM="null" || HUM="$HUM"
    fi
  fi

  # Add comma separator for all but first entry
  [ "$FIRST" = false ] && echo "," >> "$SENSOR_JSON"
  FIRST=false

  # Build JSON entry
  cat >> "$SENSOR_JSON" << EOF
  {
    "time": "$TIME",
    "img": "$img",
    "temp": $TEMP,
    "hum": $HUM
  }
EOF
done

echo "" >> "$SENSOR_JSON"
echo "]" >> "$SENSOR_JSON"

ENTRY_COUNT=$(jq 'length' "$SENSOR_JSON")
echo "Created sensor_data.json with $ENTRY_COUNT entries"

# Upload to R2
rclone copy "$SENSOR_JSON" "$R2_REMOTE" --config "$RCLONE_CONF"

echo "Uploaded recovered sensor_data.json to R2"
echo "Done!"
