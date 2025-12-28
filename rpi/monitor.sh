#!/bin/bash

# Configuration
WORK_DIR="/mnt/hdd/plants"
R2_REMOTE="zhivaya:zhivaya"
SENSOR_URL="http://192.168.100.12/api/sensor"
RCLONE_CONF="$HOME/.config/rclone/rclone.conf"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

START_HOUR=6
END_HOUR=23

DATE_STR=$(date +"%Y%m%d_%H%M%S")
DB_FILE="$WORK_DIR/sensor_data.db"
SENSOR_LOG="sensor_log.csv"

# Start process
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Initialize database
if [ ! -f "$DB_FILE" ]; then
    echo "Initializing database..."
    sqlite3 "$DB_FILE" < "$SCRIPT_DIR/schema.sql"
fi

# 1. Get sensor data
RAW_DATA=$(curl -s --max-time 5 "$SENSOR_URL")
if [ -z "$RAW_DATA" ]; then
    TEMP="null"
    HUM="null"
else
    TEMP=$(echo "$RAW_DATA" | jq -r '.temperature')
    HUM=$(echo "$RAW_DATA" | jq -r '.humidity')
fi

# 2. Taking a photo
CURRENT_HOUR=$(date +%-H)
IMG_FILENAME=""

if [ "$CURRENT_HOUR" -ge "$START_HOUR" ] && [ "$CURRENT_HOUR" -le "$END_HOUR" ]; then
    IMG_FILENAME="img_${DATE_STR}.jpg"

    # IMPORTANT: Don't use --latest option (creates symlink)
    rpicam-still --vflip --hflip -t 2000 --width 3280 --height 2464 -o "$IMG_FILENAME"

    # IMPORTANT: Copy as actual file (not symlink)
    # -f: force overwrite
    # -L: dereference symlinks
    cp -fL "$IMG_FILENAME" "latest.jpg"

    # Upload image
    rclone copy "$IMG_FILENAME" "$R2_REMOTE" --config "$RCLONE_CONF"

    # IMPORTANT: Upload latest.jpg as file (not directory)
    rclone copyto "latest.jpg" "$R2_REMOTE/latest.jpg" --config "$RCLONE_CONF"

    echo "Snapshot taken: $IMG_FILENAME"
else
    echo "Night mode: Sensor logging only."
fi

# 3. Save to database and CSV backup
echo "${DATE_STR},${IMG_FILENAME},${TEMP},${HUM}" >> "$SENSOR_LOG"

# Prepare values for SQLite (convert "null" string to NULL)
IMG_VALUE="${IMG_FILENAME:-NULL}"
[ "$IMG_VALUE" = "" ] && IMG_VALUE="NULL"
[ "$IMG_VALUE" != "NULL" ] && IMG_VALUE="'$IMG_VALUE'"

TEMP_VALUE="${TEMP}"
[ "$TEMP_VALUE" = "null" ] && TEMP_VALUE="NULL"

HUM_VALUE="${HUM}"
[ "$HUM_VALUE" = "null" ] && HUM_VALUE="NULL"

# Insert into SQLite
sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO sensor_data (timestamp, image_filename, temperature, humidity)
VALUES ('$DATE_STR', $IMG_VALUE, $TEMP_VALUE, $HUM_VALUE);
EOF

if [ $? -eq 0 ]; then
    echo "Saved to database: ${TEMP}C / ${HUM}%"
else
    echo "Error: Failed to save to database"
fi