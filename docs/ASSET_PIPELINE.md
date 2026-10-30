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
- World and car vector drawing is done during setup/scene construction, not repeatedly rebuilt every frame.

## Verification and remaining gates

The GitHub Actions workflow validates the asset catalogue, source syntax, unit tests, and desktop/mobile Playwright smoke tests. The 30 October 2026 run `41080916182` completed successfully: 45 Node tests passed, the desktop/mobile browser smoke test passed, and two gameplay preview images were uploaded as the `mshin-gameplay-previews` artifact.

This CI result does **not** replace the following release gates:
- Importing the project in Cocos Creator 3.8.6 Editor.
- Building and opening the Creator Web target.
- Building an Android APK/AAB and testing on a physical device.
- Measuring sustained frame time and memory on representative low/mid-range phones.
