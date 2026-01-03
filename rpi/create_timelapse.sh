#!/bin/bash

# Create timelapse video from plant monitoring images
# Usage: ./create_timelapse.sh [OPTIONS]

set -e

# Configuration
WORK_DIR="/mnt/hdd/plants"
R2_REMOTE="zhivaya:zhivaya"
RCLONE_CONF="$HOME/.config/rclone/rclone.conf"
DB_FILE="$WORK_DIR/sensor_data.db"

# Default settings
FPS=30
OUTPUT_NAME="timelapse_$(date +%Y%m%d_%H%M%S).mp4"
START_DATE=""
END_DATE=""
USE_R2=false
UPLOAD_TO_R2=true
RESOLUTION="1920x1440"  # 4:3 aspect ratio

# Help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Create a timelapse video from plant monitoring images.

Options:
    -f, --fps FPS           Frame rate (default: 30)
    -o, --output FILE       Output filename (default: timelapse_YYYYMMDD_HHMMSS.mp4)
    -s, --start DATE        Start date (format: YYYYMMDD, optional)
    -e, --end DATE          End date (format: YYYYMMDD, optional)
    -r, --resolution WxH    Video resolution (default: 1920x1440)
    --use-r2                Download images from R2 instead of using local files
    --no-upload             Don't upload the result to R2
    -h, --help              Show this help message

Examples:
    # Create timelapse from all images
    ./create_timelapse.sh

    # Create timelapse for specific date range at 60fps
    ./create_timelapse.sh -s 20260101 -e 20260131 -f 60

    # Download from R2 and create timelapse
    ./create_timelapse.sh --use-r2

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--fps)
            FPS="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_NAME="$2"
            shift 2
            ;;
        -s|--start)
            START_DATE="$2"
            shift 2
            ;;
        -e|--end)
            END_DATE="$2"
            shift 2
            ;;
        -r|--resolution)
            RESOLUTION="$2"
            shift 2
            ;;
        --use-r2)
            USE_R2=true
            shift
            ;;
        --no-upload)
            UPLOAD_TO_R2=false
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Check dependencies
for cmd in sqlite3 ffmpeg rclone; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed"
        exit 1
    fi
done

cd "$WORK_DIR"

# Create temporary directory for processing
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "=== Timelapse Video Creation ==="
echo "Working directory: $WORK_DIR"
echo "Temporary directory: $TEMP_DIR"
echo "Frame rate: ${FPS}fps"
echo "Resolution: $RESOLUTION"
echo "Output: $OUTPUT_NAME"

# Build SQL query based on date range
SQL_WHERE="WHERE image_filename IS NOT NULL"
if [ -n "$START_DATE" ]; then
    SQL_WHERE="$SQL_WHERE AND timestamp >= '${START_DATE}_000000'"
fi
if [ -n "$END_DATE" ]; then
    SQL_WHERE="$SQL_WHERE AND timestamp <= '${END_DATE}_235959'"
fi

# Get image list from database
echo ""
echo "Fetching image list from database..."
IMAGE_LIST=$(sqlite3 "$DB_FILE" <<EOF
SELECT image_filename
FROM sensor_data
$SQL_WHERE
ORDER BY timestamp ASC;
EOF
)

if [ -z "$IMAGE_LIST" ]; then
    echo "Error: No images found for the specified criteria"
    exit 1
fi

IMAGE_COUNT=$(echo "$IMAGE_LIST" | wc -l)
echo "Found $IMAGE_COUNT images"

# Prepare images
echo ""
if [ "$USE_R2" = true ]; then
    echo "Downloading images from R2..."
    DOWNLOAD_COUNT=0
    while IFS= read -r img; do
        if [ -n "$img" ]; then
            rclone copyto "${R2_REMOTE}/${img}" "${TEMP_DIR}/${img}" --config "$RCLONE_CONF" -q
            DOWNLOAD_COUNT=$((DOWNLOAD_COUNT + 1))
            echo -ne "\rDownloaded: $DOWNLOAD_COUNT/$IMAGE_COUNT"
        fi
    done <<< "$IMAGE_LIST"
    echo ""
    IMAGE_DIR="$TEMP_DIR"
else
    echo "Using local images..."
    # Create symlinks to avoid copying large files
    while IFS= read -r img; do
        if [ -n "$img" ] && [ -f "$img" ]; then
            ln -sf "$WORK_DIR/$img" "$TEMP_DIR/$img"
        fi
    done <<< "$IMAGE_LIST"
    IMAGE_DIR="$TEMP_DIR"
fi

# Verify we have images
ACTUAL_COUNT=$(find "$IMAGE_DIR" -name "img_*.jpg" 2>/dev/null | wc -l)
if [ "$ACTUAL_COUNT" -eq 0 ]; then
    echo "Error: No images found in $IMAGE_DIR"
    exit 1
fi

echo "Processing $ACTUAL_COUNT images..."

# Create file list for ffmpeg
LIST_FILE="$TEMP_DIR/file_list.txt"
find "$IMAGE_DIR" -name "img_*.jpg" | sort | while read -r img; do
    echo "file '$img'" >> "$LIST_FILE"
done

# Extract width and height from resolution
WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)

# Create timelapse video
echo ""
echo "Creating timelapse video..."
ffmpeg -f concat -safe 0 -i "$LIST_FILE" \
    -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2" \
    -c:v libx264 -preset slow -crf 18 \
    -r "$FPS" -pix_fmt yuv420p \
    "$TEMP_DIR/$OUTPUT_NAME" \
    -y -loglevel warning -stats

if [ ! -f "$TEMP_DIR/$OUTPUT_NAME" ]; then
    echo "Error: Failed to create video"
    exit 1
fi

# Move to work directory
mv "$TEMP_DIR/$OUTPUT_NAME" "$WORK_DIR/$OUTPUT_NAME"

FILE_SIZE=$(du -h "$WORK_DIR/$OUTPUT_NAME" | cut -f1)
echo ""
echo "✓ Video created successfully: $OUTPUT_NAME ($FILE_SIZE)"

# Upload to R2
if [ "$UPLOAD_TO_R2" = true ]; then
    echo ""
    echo "Uploading to R2..."
    rclone copy "$WORK_DIR/$OUTPUT_NAME" "$R2_REMOTE" --config "$RCLONE_CONF"
    echo "✓ Uploaded to R2: $OUTPUT_NAME"
fi

echo ""
echo "=== Complete ==="
echo "Output: $WORK_DIR/$OUTPUT_NAME"
echo "Duration: $(echo "scale=2; $ACTUAL_COUNT / $FPS" | bc) seconds"
echo "Total frames: $ACTUAL_COUNT"
