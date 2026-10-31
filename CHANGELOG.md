## 0.8.5 — 2026-10-31

### Mobile localization and release integrity
- Replaced the remaining English portrait-orientation hint with Persian guidance to rotate the phone for the intended landscape racing view.
- Synchronized the visible splash/menu release labels, package metadata, PWA manifest and asset catalog version markers at 0.8.5 / 2026.10.31.10.
- Advanced the offline service-worker cache to v24 so returning PWA installations receive the updated release shell.
- Added automated checks for release-label and metadata consistency, and a browser assertion that the published version badge is visible.

## 0.8.5 — 2026-10-31

### Mobile localization and release integrity
- Replaced the remaining English portrait-orientation hint with Persian guidance to rotate the phone for the intended landscape racing view.
- Synchronized the visible splash/menu release labels, package metadata, PWA manifest and asset catalog version markers at 0.8.5 / 2026.10.31.10.
- Advanced the offline service-worker cache to v24 so returning PWA installations receive the updated release shell.
- Added automated checks for release-label and metadata consistency, and a browser assertion that the published version badge is visible.

## 0.8.4 — 2026-10-31\n\n### Published version visibility and cache refresh\n- Show the published release number (0.8.4) on the startup splash screen and the main menu after loading.\n- Add a direct link from the in-game version badge to this changelog so players can verify what is included in the published build.\n- Advance the PWA manifest, package metadata, asset catalogs and boot query marker together; bump the service-worker cache to v23 so returning installations refresh to this release.\n\n## 0.8.3 — 2026-10-31

### Vehicle identity and race presentation
- Added individual sound profiles for Rally, GT, 4x4 and Desert Raptor vehicles; pitch, throttle character, filter response and loudness now differ by vehicle.
- Added a dedicated speed-linked electric motor whine for the Thunder EV instead of combustion-engine loops.
- Added a cinematic close-up race intro showing the selected car and nearby competitors during 3–2–1–GO.

### Progressive traffic and rewards
- Introduced additional traffic classes by stage: pickup from stage 11, Formula car from stage 21, truck from stage 31, and bus plus motorcycle from stage 41.
- Added distinct silhouettes, vehicle dimensions and mass/speed profiles so heavy vehicles and motorcycles react differently in collisions.
- Strong player-initiated front impacts award persistent bonus coins with a cooldown and on-screen reward feedback.
- Updated ranking to keep the three championship rivals separate from additional track traffic; advanced runtime version to 0.8.3 and offline cache to v22.

## 0.8.2 — 2026-10-31

- Refined recorded engine loops with trimmed loop points to remove silence at loop boundaries.
- Added equal-power six-layer RPM crossfades, six automatic gear bands, downshift cues, throttle/load/boost response, engine braking decay and RPM-sensitive exhaust filtering.
- Added smoothed gain/pitch/filter automation and gentle dynamics compression; braking and nitro now influence engine audio.
- Advanced runtime, PWA and service-worker cache markers to 0.8.2 / 2026.10.31.7 / v21.

## 0.8.1 — 2026-10-31

- Replaced AI-generated engine clips with six recorded CC0 engine RPM loops from OpenGameArt, served by immutable jsDelivr CDN URLs and cross-faded by speed.
- Preloads and decodes all six engine layers plus brake/downshift effects before countdown.
- Pulls the chase camera back to 0.96 scale and balances four lane corridors to equal widths.
- Advances release/cache markers to 0.8.1 / 2026.10.31.6 / v20.

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
- Audio clips are from the SFXMint CC0 1.0 library; they are AI-generated effects, not real-world field recordings.

### Loading and offline
- Preloads ten world illustrations, five car sprites, ten photographic scenes, three control icons and four sound clips before importing the game loop.
- Advanced service-worker cache to `mshin-arcade-v19`.

### Verification boundaries
- Desktop/mobile Playwright, network-request, countdown, four-lane telemetry and asset-preload checks are release gates.
- Cocos Creator Editor builds and physical-device QA are not represented as completed by browser CI.

