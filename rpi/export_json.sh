#!/bin/bash

# Export sensor data from SQLite to JSON and upload to R2

WORK_DIR="/mnt/hdd/plants"
R2_REMOTE="zhivaya:zhivaya"
RCLONE_CONF="$HOME/.config/rclone/rclone.conf"
DB_FILE="$WORK_DIR/sensor_data.db"
SENSOR_JSON="sensor_data.json"
IMAGES_JSON="images.json"

cd "$WORK_DIR"

echo "Exporting sensor_data.json from SQLite..."

# Export sensor data to JSON
sqlite3 "$DB_FILE" <<'EOF' > "$SENSOR_JSON"
.mode json
SELECT
    timestamp as time,
    image_filename as img,
    temperature as temp,
    humidity as hum
FROM sensor_data
ORDER BY timestamp ASC;
EOF

if [ $? -eq 0 ]; then
    ENTRY_COUNT=$(jq 'length' "$SENSOR_JSON")
    echo "Exported $ENTRY_COUNT entries to sensor_data.json"

    # Upload to R2
    rclone copy "$SENSOR_JSON" "$R2_REMOTE" --config "$RCLONE_CONF"
    echo "Uploaded sensor_data.json to R2"
else
    echo "Error: Failed to export sensor_data.json"
    exit 1
fi

# Generate images.json from R2 bucket
echo "Fetching image list from R2..."
if rclone lsjson "$R2_REMOTE" --config "$RCLONE_CONF" | \
  jq -e '[.[] | select(.Name | test("^img_.*\\.jpg$")) | .Name] | sort' \
  > "$IMAGES_JSON"; then

  IMAGE_COUNT=$(jq 'length' "$IMAGES_JSON")
  echo "Found $IMAGE_COUNT images in R2"

  rclone copy "$IMAGES_JSON" "$R2_REMOTE" --config "$RCLONE_CONF"
  echo "Uploaded images.json to R2"
else
  echo "Error: Failed to generate images.json"
fi

echo "Done!"
