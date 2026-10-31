## 0.10.1 — WebGL 3D garage preview (in validation)

### Real-time 3D showroom
- Replaced the perspective-transformed 2D car artwork in the garage with a dependency-free WebGL 1 scene: low-poly body shell, cabin glazing, wheels, alloy hubs, lights, spoiler, lit studio floor and perspective camera.
- Added live paint-color changes for all five selectable vehicles, pointer/touch orbit rotation, and an animated 360-degree spin.
- Added an image fallback for browsers without WebGL and visibility-aware rendering to avoid wasting battery while the garage is closed.
- Added a Playwright WebGL/SwiftShader acceptance check and advanced the offline PWA cache to `mshin-arcade-v36`.
- Release gate: browser CI, merged-main validation and GitHub Pages deployment must pass; Cocos Creator Editor import/build remains a separate unverified gate.

## 0.9.3 — published (2026-10-31)

### Repository-local runtime assets
- Vendored 10 photographic world scenes, 3 control SVGs, and 10 engine/music/braking audio files into `cdn/assets/`.
- Repointed the runtime asset manifest to same-origin repository paths and removed external CDN fallback from the service worker.
- Advanced the PWA shell cache to `mshin-arcade-v33`; the complete local asset set is precached for offline launch and gameplay.
- Synchronized package/PWA version `0.9.3`, asset marker `2026.10.31.17`, and Cocos vector catalog marker.
- Verification: all 136 Node tests and desktop/mobile Playwright passed; merged-main validation run `41206965694` succeeded; GitHub Pages deployment run `41206965179` succeeded for commit `07695e04a4645dedd6fc0fed6a85ffbd8f895412`.

## 0.8.8 — 2026-10-31

### Cinematic vehicle showroom
- Added a dedicated selected-car studio with cinematic spotlight, reflective floor glow and a layered 3D perspective presentation.
- Added interactive drag rotation plus a one-tap 360° showroom spin, with touch and pointer support.
- Added short, vehicle-specific engine previews using the already-preloaded CC0 engine layers; the electric vehicle receives a synthesized electric whine preview.
- Preserved selected vehicle and progression behavior; extended desktop/mobile browser coverage for showroom selection, rotation and audio preview controls.
- Advanced PWA cache to v27 and synchronized package/manifest metadata to 0.8.8.

## 0.8.7 — 2026-10-31

### Premium 3D showroom and menu polish
- Added a perspective-driven showroom with layered lighting, metallic reflections, stronger contact shadows and 3D vehicle artwork.
- Refined hover and selected states across vehicle, world, stage, workshop and achievement cards.
- Tuned card sizing and horizontal touch rails for narrow mobile screens; respects reduced-motion preferences.
- Extended Playwright coverage for desktop perspective, five-car integrity, mobile rail sizing and five-stage selection.
- Bumped PWA shell cache to v26 and synchronized package/manifest metadata to 0.8.7.

## 0.8.6 — 2026-10-31

### GT-inspired menu redesign
- Rebuilt the game selection interface as a single-screen, five-tab motorsport menu: Race, Cars, Workshop, Awards and Settings.
- Replaced text-first stacked choices with horizontal, image-led 3D-styled cards; world and vehicle artwork contains no embedded labels, with concise Persian descriptions below each image.
- Added keyboard-accessible tab navigation, active-state feedback, horizontal snap rails and responsive mobile layouts.
- Moved world/stage selection, vehicle selection, tuning, achievements and sound settings into dedicated tabs without changing race progression or saved player data.
- Removed the latest-changes link from the first/home screen.
- Updated PWA cache to v25 and asset marker to 2026.10.31.11.

## 0.8.5 — 2026-10-31

### Mobile localization and release integrity
- Replaced the remaining English portrait-orientation hint with Persian guidance to rotate the phone for the intended landscape racing view.
- Synchronized the visible splash/menu release labels, package metadata, PWA manifest and asset catalog version markers at 0.8.5 / 2026.10.31.10.
- Advanced the offline service-worker cache to v24 so returning PWA installations receive the updated release shell.
- Added automated checks for release-label and metadata consistency, and a browser assertion that the published version badge is visible.

## 0.8.4 — 2026-10-31

### Published version visibility and cache refresh
- Show the published release number (0.8.4) on the startup splash screen and the main menu after loading.
- Add a direct link from the in-game version badge to this changelog so players can verify what is included in the published build.
- Advance the PWA manifest, package metadata, asset catalogs and boot query marker together; bump the service-worker cache to v23 so returning installations refresh to this release.

## 0.8.3 — 2026-10-31

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

## 0.9.3 — 2026-10-31 · Motorsport menu polish

- Reworked the browser five-tab menu into a vertical angular navigation rail with a separate content panel and compact mobile layout (PR #54).
- Refreshed the PWA shell cache to `mshin-arcade-v34` so returning installations receive the current menu.
- Began aligning the Cocos Creator runtime menu screens with the same dark navy, red-accented motorsport visual language; Editor/device verification remains a separate gate.



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

