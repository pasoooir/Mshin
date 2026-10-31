# Changelog

## 0.8.0 — 2026-10-31

### Race presentation
- Widened the asphalt to a four-lane road with four traffic lane centers.
- Pulled the chase camera back to keep the full asphalt width visible.
- Added a cinematic animated 3, 2, 1, GO countdown; player and AI cars remain stationary until GO.
- Replaced gas, brake and nitro labels with accessible SVG control icons from jsDelivr.

### Audio
- Replaced the synthetic oscillator engine with preloaded CDN race-car idle and full-throttle recordings.
- Added race-car braking/tire-squeal and downshift clips.
- Preloads audio bytes before gameplay and decodes the sound bank on the first menu gesture while a stage is selected.
- Audio clips are from the SFXMint CC0 1.0 library.

### Loading and offline
- Preloads ten world illustrations, five car sprites, ten photographic scenes, three control icons and four sound clips before importing the game loop.
- Advanced service-worker cache to `mshin-arcade-v19`.

### Verification boundaries
- Desktop/mobile Playwright, network-request, countdown, four-lane telemetry and asset-preload checks are release gates.
- Cocos Creator Editor builds and physical-device QA are not represented as completed by browser CI.

