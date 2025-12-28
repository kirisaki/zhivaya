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

## Raspberry Pi Monitor Script

The `scripts/monitor.sh` script captures images and sensor data from a Raspberry Pi.

### Setup

1. Edit `scripts/monitor.sh` configuration section:
   - `SENSOR_URL`: Your sensor API endpoint
   - `WORK_DIR`: Directory for storing images and data
   - `R2_REMOTE`: Your rclone remote name
   - `RCLONE_CONF`: Path to your rclone config

2. Add to crontab (runs every 10 minutes):
   ```sh
   */10 * * * * /path/to/zhivaya/scripts/monitor.sh
   ```

### Recovery

If `sensor_data.json` gets corrupted, you can rebuild it from R2 image files:

```sh
cd scripts
./recover_sensor_data.sh
```

This will:
- Fetch all images from R2
- Recover `temp` and `hum` from `sensor_log.csv` if available
- Create entries with `null` values for missing sensor data

### Requirements

- Raspberry Pi with camera module
- `rpicam-still` (libcamera)
- `rclone` configured for Cloudflare R2
- `jq` for JSON processing
- `curl` for API requests

## Tech Stack

- Astro
- Preact
