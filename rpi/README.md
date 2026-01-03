# Raspberry Pi Scripts for Plant Monitoring

This directory contains scripts for monitoring plants with Raspberry Pi, including sensor data collection, image capture, and timelapse video creation.

## Scripts

### monitor.sh
Main monitoring script that runs periodically (via cron) to:
- Capture sensor data (temperature, humidity)
- Take photos during daytime (6:00-23:00)
- Save data to SQLite database
- Upload images to R2 storage

**Setup:**
```bash
# Add to crontab (every 5 minutes)
*/5 * * * * /path/to/monitor.sh
```

### export_json.sh
Export sensor data from SQLite to JSON format and upload to R2:
- Creates `sensor_data.json` from database
- Generates `images.json` list from R2 bucket
- Uploads both to R2 storage

**Usage:**
```bash
./export_json.sh
```

### create_timelapse.sh
Create timelapse videos from captured images.

**Features:**
- Date range filtering
- Configurable frame rate and resolution
- Download from R2 or use local files
- Auto-upload result to R2

**Usage:**
```bash
# Create timelapse from all images
./create_timelapse.sh

# Specific date range at 60fps
./create_timelapse.sh -s 20260101 -e 20260131 -f 60

# Download from R2 before processing
./create_timelapse.sh --use-r2

# Custom output name and resolution
./create_timelapse.sh -o my_video.mp4 -r 1280x960

# Don't upload to R2
./create_timelapse.sh --no-upload
```

**Options:**
- `-f, --fps FPS` - Frame rate (default: 30)
- `-o, --output FILE` - Output filename
- `-s, --start DATE` - Start date (YYYYMMDD)
- `-e, --end DATE` - End date (YYYYMMDD)
- `-r, --resolution WxH` - Video resolution (default: 1920x1440)
- `--use-r2` - Download images from R2
- `--no-upload` - Don't upload result to R2
- `-h, --help` - Show help

### recover_sensor_data.sh
Recovery script to restore sensor data from CSV backup to SQLite database.

**Usage:**
```bash
./recover_sensor_data.sh
```

## Database Schema

See `schema.sql` for the SQLite database structure:
- `sensor_data` table with timestamp, image_filename, temperature, humidity

## Configuration

Scripts use these default paths and settings:
- **Work directory:** `/mnt/hdd/plants`
- **R2 remote:** `zhivaya:zhivaya`
- **rclone config:** `~/.config/rclone/rclone.conf`
- **Image format:** `img_YYYYMMDD_HHMMSS.jpg`
- **Camera hours:** 6:00-23:00

## Dependencies

Required packages:
- `rpicam-apps` (for rpicam-still)
- `sqlite3`
- `rclone`
- `jq`
- `ffmpeg` (for timelapse creation)
- `bc` (for calculations)

Install on Raspberry Pi:
```bash
sudo apt update
sudo apt install sqlite3 rclone jq ffmpeg bc
```

## Example Workflow

1. **Set up monitoring:**
   ```bash
   # Add to crontab
   crontab -e
   # Add: */5 * * * * /path/to/rpi/monitor.sh
   ```

2. **Export data regularly:**
   ```bash
   # Add to crontab (every hour)
   0 * * * * /path/to/rpi/export_json.sh
   ```

3. **Create monthly timelapse:**
   ```bash
   # On the 1st of each month, create previous month's timelapse
   ./create_timelapse.sh -s 20260101 -e 20260131 -f 30 -o timelapse_2026_01.mp4
   ```

## Notes

- Images are stored locally and uploaded to R2
- Database provides query capabilities and backup via CSV
- Timelapse script preserves image quality with CRF 18
- All scripts handle graceful failures (network issues, sensor errors)
