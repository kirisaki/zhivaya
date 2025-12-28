#!/bin/bash

# Configuration
WORK_DIR="/mnt/hdd/plants"
R2_REMOTE="zhivaya:zhivaya"
SENSOR_URL="http://192.168.100.12/api/sensor"
RCLONE_CONF="$HOME/.config/rclone/rclone.conf"

START_HOUR=6
END_HOUR=23

DATE_STR=$(date +"%Y%m%d_%H%M%S")
SENSOR_LOG="sensor_log.csv"
SENSOR_JSON="sensor_data.json"
IMAGES_JSON="images.json"

# Start porocess
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

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

# 3. Save CSV and JSON
echo "${DATE_STR},${IMG_FILENAME},${TEMP},${HUM}" >> "$SENSOR_LOG"

jq -R 'split(",") | {
    time: .[0],
    img: (if .[1] == "" then null else .[1] end),
    temp: (if .[2] == "null" then null else (.[2] | tonumber) end),
    hum: (if .[3] == "null" then null else (.[3] | tonumber) end)
}' "$SENSOR_LOG" | jq -s . > "$SENSOR_JSON"

rclone copy "$SENSOR_JSON" "$R2_REMOTE" --config "$RCLONE_CONF"

# 4. Update images JSON from R2 bucket (source of truth)
rclone lsjson "$R2_REMOTE" --config "$RCLONE_CONF" | \
  jq '[.[] | select(.Name | startswith("img_") and endswith(".jpg")) | .Name] | sort' \
  > "$IMAGES_JSON"

rclone copy "$IMAGES_JSON" "$R2_REMOTE" --config "$RCLONE_CONF"

echo "Log updated: ${TEMP}C / ${HUM}%"