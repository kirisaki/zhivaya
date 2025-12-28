# Zhivaya

Sensor data viewer with image timeline.

## Features

- Display sensor images from Cloudflare R2
- Show temperature and humidity data
- Slider to navigate through historical data
- Auto-refresh every 5 minutes

## Development

```sh
npm install
npm run dev
```

## Deployment

### Cloudflare Pages

Build settings:
- Build command: `npm run build`
- Build output directory: `dist`
- Node version: 18 or later

## Raspberry Pi Setup

The `rpi/` directory contains scripts for Raspberry Pi to capture images and sensor data.

### Requirements

- Raspberry Pi with camera module
- `rpicam-still` (libcamera)
- `sqlite3`
- `rclone` configured for Cloudflare R2
- `jq` for JSON processing
- `curl` for API requests

### Setup

1. Edit `rpi/monitor.sh` configuration:
   - `SENSOR_URL`: Your sensor API endpoint
   - `WORK_DIR`: Directory for storing images and database
   - `R2_REMOTE`: Your rclone remote name

2. Add to crontab:
   ```sh
   # Capture data every 10 minutes
   */10 * * * * /path/to/zhivaya/rpi/monitor.sh

   # Export JSON to R2 every 10 minutes (offset by 5 min)
   5,15,25,35,45,55 * * * * /path/to/zhivaya/rpi/export_json.sh
   ```

### How It Works

1. **monitor.sh**: Captures images (daytime only) and sensor data → SQLite database
2. **export_json.sh**: Exports SQLite data to JSON → uploads to R2
3. Frontend fetches JSON from R2

Data flow: `Sensors → SQLite → JSON → R2 → Frontend`

### Recovery

If the SQLite database gets corrupted, rebuild from CSV backup:

```sh
cd rpi
./recover_sensor_data.sh
./export_json.sh
```

## Tech Stack

- Astro
- Preact
