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

## Tech Stack

- Astro
- Preact
