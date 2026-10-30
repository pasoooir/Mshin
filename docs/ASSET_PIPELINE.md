# Mshin vector art and asset loading

## Asset sources

- Browser edition: 10 hand-authored scalable SVG world illustrations and five vehicle sprites in `assets/vector/`.
- Browser manifest: `src/asset-manifest.json`, versioned independently from the app shell.
- Cocos Creator: `assets/resources/vector-art.json`, imported by Creator as a `JsonAsset`. The game reads the palette catalogue before opening the main menu and uses Cocos `Graphics` to draw its vector-style vehicle and themed world landmarks.
- Browser art is delivered from immutable, commit-pinned jsDelivr URLs first. If the CDN is slow, blocked, or offline, the loader falls back to the same-origin SVGs in the repository. No required art depends solely on a third-party CDN. The local copies remain the source of truth and are precached by the Service Worker. No Cloudflare R2 is used.

## Browser preload sequence

1. Show the dedicated loading screen.
2. Fetch the versioned manifest and all 15 SVG assets with a concurrency limit of three; prefer commit-pinned jsDelivr URLs and abort a stalled CDN request after 2.2 seconds before trying the local copy.
3. Decode each image before adding it to `window.MshinAssets`.
4. Report progress as each image finishes.
5. Import `src/web-game.js` only after the preload pass completes.
6. Keep procedural Canvas fallbacks if an individual image fails.
7. Service Worker cache `mshin-arcade-v5` precaches the app shell, manifest, loader, all 10 world SVGs and all five car SVGs. A warmed installation remains playable offline.

The game does not deliberately defer image fetch/decode into the race loop. Race start is covered by a browser smoke assertion for late network requests.

## Cocos preload sequence

The Cocos runtime calls `resources.load("vector-art", JsonAsset, ...)` from `assets/scripts/MshinGame.ts`. The loading screen remains visible until the JSON catalogue is resolved (or the procedural Graphics fallback is selected after a load error). `WorldRenderer` uses the loaded world palette and landmark metadata; the player vehicle renderer uses the loaded car palette.

The JSON is lightweight vector drawing metadata rather than a bitmap atlas. This keeps the Creator import path independent of SVG importer behavior and avoids shipping a second raster copy of the same art.

## Performance guardrails

- Browser loader concurrency is capped at three to avoid a burst of simultaneous decodes on mobile.
- Particle objects are reused and the active particle count is capped.
- Collision cooldowns are advanced in the frame update rather than scheduling one timeout per hit.
- HUD DOM writes are throttled to 10 Hz in the browser runtime.
- Cocos HUD label updates are throttled to 10 Hz.
- Static world and track geometry is rasterized once per selected stage into a half-resolution offscreen canvas (about 5.2 MB RGBA) and reused each frame; pickups and obstacles remain dynamic. The browser runtime publishes a rolling 120-frame JS-work telemetry window (`window.MshinPerformance`) with average, p95, max frame work, effective FPS, collisions, and pickups; the Playwright smoke test enforces generous anti-stall ceilings during a live race.
- World and car vector drawing is done during setup/scene construction, not repeatedly rebuilt every frame.

## Verification and remaining gates

The GitHub Actions workflow validates the asset catalogue, source syntax, unit tests, and desktop/mobile Playwright smoke tests. The 30 October 2026 run `41083606663` completed successfully: all 45 Node tests passed, the desktop/mobile Playwright smoke test passed, the static-track-cache assertion passed, and four visual previews (home, world selection, desktop race, mobile race) were uploaded as the `mshin-gameplay-previews` artifact. The Cocos syntax guard also checks duplicate class member names; this caught and prevented a duplicate field/method regression in `MshinGame.ts`.

The latest smoke run includes an assertion that static track/world art is rasterized once per race stage and reused between frames; only pickups and obstacles are drawn dynamically. It also verifies that all ten world cards load their own SVG preview.

This CI result does **not** replace the following release gates:
- Importing the project in Cocos Creator 3.8.6 Editor.
- Building and opening the Creator Web target.
- Building an Android APK/AAB and testing on a physical device.
- Measuring sustained frame time and memory on representative low/mid-range phones.


## Touch steering usability update

The old circular joystick accepted two-axis thumb movement but only consumed the horizontal axis, which made the control feel inconsistent. The browser and Cocos controls now present a horizontal steering pad: drag left/right to steer; vertical thumb movement is ignored. A small center dead zone filters accidental drift, response is progressive rather than instantly full-lock, and steering eases smoothly back to center after release. Browser steering also uses a gradual lateral-velocity response instead of instantly shifting the car sideways. The browser smoke test checks rightward input, the center dead zone, release-to-center, accessible instructions, and mobile touch target width. These steering assertions passed in Actions run `41085782040` (45/45 Node tests and desktop/mobile Playwright smoke). This is a usability improvement validated in automated browser tests, not a substitute for hands-on testing on the user's phone.


## Photographic environments and zoomed race camera

The browser boot now preloads ten photographic environment plates from the Unsplash image CDN alongside the 15 local SVG vectors and decodes them before importing the race runtime. Each world has a dedicated photo plate; rain, snow, sand and dust particle/weather overlays remain separate real-time effects. The image loader uses bounded concurrency and a short CDN timeout; if a photo cannot be fetched or decoded, the local vector world illustration remains the fallback. No image request or decode is initiated by the race render loop.

The race camera is zoomed toward the player instead of fitting the complete oval track into one screen. The player car is rendered at 58×90 logical pixels (up from 40×62), rival cars are larger, and the track is revealed progressively as the car follows its bends. This is a browser runtime change; physical Android frame-rate and Cocos Creator Editor validation remain separate checks.


## Forward-facing chase camera and vehicle scale

The browser race camera now follows the route tangent and rotates the world around the player so the player's car stays pointed toward the top of the screen while bends flow underneath it. This avoids showing the car sideways merely because the track curves. The player car is rendered at 72×108 logical pixels and rivals at 56×84; the camera still reveals only the nearby track segment rather than fitting the complete circuit into view. Automated desktop/mobile browser smoke coverage asserts the camera transform and vehicle render dimensions.
