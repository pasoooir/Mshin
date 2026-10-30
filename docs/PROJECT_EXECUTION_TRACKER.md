# Mshin — Project Execution Tracker

Last evidence refresh: 2026-10-30

## Repository and delivery state

- Default branch `main` includes merge commit `36fa6d7673ec4fd0f91db73be4487d8d67eef22a` (PR #7), following PR #6 merge commit `722ec96f62a1a78c2832219cb41eb17ac31c7da8`.
- PR #1 (Cocos/game foundation), PR #2 (50-stage browser edition), PR #3 (Playwright browser QA), PR #4 (browser race audio and mute control), PR #5 (visible car animation and particles), PR #6 (garage, nitro and offline PWA), and PR #7 (AI rivals, live position, minimap and mobile HUD refinement) are merged. PR #7 adds AI rivals, live race position and a minimap; it is awaiting merge after validation.
- PR #4 adds dependency-free Web Audio engine tone, collision and finish effects, lazy AudioContext initialization after user interaction, and an accessible mute toggle.
- PR #4 validation passed: merged-main run `41064474829`; source-branch push and PR validation runs `41063447733` and `41063457438` also passed.
- PR #5 adds animated car details, world-accent lighting, exhaust trails, collision bursts and a finish celebration; it also verifies non-blank canvas pixels and captures desktop/mobile gameplay previews.
- PR #5 push and PR validation run `41065176095` and `41065195236` passed; screenshot artifact `mshin-gameplay-previews` is attached to PR run `41065195236` (expires 2026-11-06).
- Merged-main validation run `41065496716` passed. Pages build and deploy for the PR #5 merge commit succeeded in run `41065496240`.
- PR #6 adds a three-car garage (Rally Fox, Comet GT, Lynx 4x4), distinct speed/acceleration/grip profiles, trackside nitro pickups, a charge meter and timed boost; selected car and sound preference persist locally.
- PR #6 also adds a landscape PWA manifest, vector app icon and offline-first service worker. Playwright verifies reload/offline launch and that all 10 worlds remain selectable without a network connection.
- PR #6 source push run `41067407332` and PR run `41067417413` passed; screenshot artifact `mshin-gameplay-previews` is attached to run `41067417413` (expires 2026-11-06).
- Merged-main validation run `41067626291` and Pages build/deployment run `41067626354` both succeeded for merge commit `722ec96f62a1a78c2832219cb41eb17ac31c7da8`.
- PR #7 adds three AI rival cars with independent progress, live 1–4 race position, a circuit minimap with player/rival markers, finish placement feedback, and compact portrait HUD spacing. PR browser validation run `41070776069` passed; merged-main validation run `41071069297` passed after the service-worker cache version was advanced to `mshin-arcade-v2` so returning offline users receive the updated game.
- GitHub Pages build and deployment for merge commit `36fa6d7673ec4fd0f91db73be4487d8d67eef22a` succeeded in run `41071069211`.
- Main contains `index.html`, `src/web-game.js`, `src/audio.js`, and `tests/browser-smoke.mjs`; CI captures desktop and mobile gameplay screenshots.
- PR #7 adds three AI rival cars with independent progress, colored rival vehicles, a live 1–4 position indicator, a compact circuit minimap with player/rival markers, and finishing-position feedback. Validation run `41070456724` passed syntax checks, Node tests, and desktop/mobile Playwright smoke including the new live-position assertion; screenshot artifacts were uploaded.
- No Cloudflare R2, D1, KV, Durable Objects, paid storage, or paid services are used.

## Evidence-based status

| Workstream | Status | Progress | Evidence / remaining acceptance gate |
|---|---:|---:|---|
| Repository foundation and stage catalog | 🟢 | 100% | 10 world themes and 50 deterministic stage definitions exist and pass data validation. Gameplay balancing remains tracked separately. |
| Portable driving/race core | 🟡 | 68% | Off-road handling, bounded frame-step timing and invalid-input safeguards have regression coverage; broader play balance remains. |
| Cocos Creator project/runtime integration | 🔴 | 20% | Project metadata and runtime scripts are in `assets/scripts/`; no Editor-created startup scene, engine type-check, Editor import, or Cocos preview/build has been verified. |
| Cocos world visuals and hazards | 🟡 | 38% | Theme-specific decorations, route generation and hazard drawing are implemented in source; Creator visual QA is outstanding. |
| Cocos menus, selection and HUD | 🟡 | 35% | Runtime-created screens and controls exist; Editor/device responsive QA is outstanding. |
| Browser playable edition | 🟡 | 94% | Browser game has 10 world palettes, 50 stages, three selectable cars, three AI rivals, live race position, circuit minimap, touch/keyboard controls, lap timer, pause/finish, local records, themed scenery, animated hazards, audio, particles and nitro boosts. Full race balance, real-device QA and final art polish remain. |
| Browser automated QA | 🟢 | 100% | Playwright/Chromium verifies 10 worlds/50 stages, garage selection and persistence, mute preference persistence, nitro pickup/charge/consumption, live race position among three AI rivals, visible canvas pixels, desktop/mobile screenshots, pause/resume, touch control sizing, offline PWA reload/playability and no uncaught page errors. PR #7 validation run `41070456724` passed. |
| Audio, animation and polish | 🟡 | 56% | Browser engine tone, collision/finish audio, saved mute setting, animated vehicle wheels/body lighting, AI rival cars, minimap, exhaust particles, nitro trails, collision bursts and finish celebration are implemented and covered by Chromium smoke tests. More car animations, environment effects and final polish remain. |
| Persistence and records | 🟡 | 76% | Browser localStorage stores completion, best times, selected car and audio preference; Playwright verifies settings survive reload and cached offline startup. Storage quota/private-mode edge cases and Cocos adapter verification remain. No server leaderboard. |
| Cloudflare Worker backend | 🟡 | 35% | Stateless health/config API and seven tests exist; not deployed or wired to a live game endpoint. |
| Portable automated tests | 🟢 | 100% | PR #7 validation run `41070456724` passed Node tests, syntax checks and Playwright desktop/mobile smoke tests covering AI-rival position HUD, garage, saved settings, nitro gameplay, rendered canvas, screenshots and offline PWA launch. |
| GitHub Pages delivery | 🟢 | 100% | Pages build and deploy for merge commit `36fa6d7673ec4fd0f91db73be4487d8d67eef22a` succeeded in run `41071069211`. |
| PWA installability and offline support | 🟡 | 90% | Manifest, vector icon and offline-first service worker are deployed; Playwright verified the game shell and world selector work offline after first visit. Native install prompt and device-specific install UX remain to verify. |
| Cocos Web build and browser QA | 🔴 | 0% | No Creator-generated Web output; requires Creator 3.8.6 and a real startup scene. Browser Canvas edition is separate from a Cocos build. |
| Android APK/AAB and device QA | 🔴 | 0% | No APK/AAB; Android SDK/NDK/native toolchain and device testing are unavailable in the inspected runner. |

## CI and deployment evidence

- PR #4 merged: https://github.com/pasoooir/Mshin/pull/4 — audio and mute control.
- PR #5 merged: https://github.com/pasoooir/Mshin/pull/5 — animated car, particles and visible canvas assertions.
- PR #6 merged: https://github.com/pasoooir/Mshin/pull/6 — three-car garage, persistent settings, collectible nitro boost and offline PWA; merge commit `722ec96f62a1a78c2832219cb41eb17ac31c7da8`.
- PR #7 merged: https://github.com/pasoooir/Mshin/pull/7 — AI rivals, live race position, minimap, finishing placement and portrait HUD refinement; merge commit `36fa6d7673ec4fd0f91db73be4487d8d67eef22a`.
- PR #7 browser QA: https://github.com/pasoooir/Mshin/actions/runs/41070776069 — success.
- Merged-main validation: https://github.com/pasoooir/Mshin/actions/runs/41071069297 — success.
- GitHub Pages deployment: https://github.com/pasoooir/Mshin/actions/runs/41071069211 — success.
- PR #7 (awaiting merge): https://github.com/pasoooir/Mshin/pull/7 — three AI rivals, live position indicator, minimap and finish placement.
- PR #7 validation: https://github.com/pasoooir/Mshin/actions/runs/41070456724 — success; browser QA and desktop/mobile screenshots passed.
- PR #6 push validation: https://github.com/pasoooir/Mshin/actions/runs/41067407332 — success.
- PR #6 browser QA and screenshot artifact: https://github.com/pasoooir/Mshin/actions/runs/41067417413 — success.
- Merged-main validation: https://github.com/pasoooir/Mshin/actions/runs/41067626291 — success.
- PR #4 branch push validation: https://github.com/pasoooir/Mshin/actions/runs/41063447733 — success.
- PR #4 validation: https://github.com/pasoooir/Mshin/actions/runs/41063457438 — success.
- Pages build and deployment for PR #6 merge commit: https://github.com/pasoooir/Mshin/actions/runs/41067626354 — success.
- Browser smoke covers 10 worlds, five stages/world, three-car garage and saved car selection, saved mute setting, nitro pickup and boost consumption, non-blank rendered canvas, desktop/mobile screenshots, pause/resume, mobile nitro sizing and offline PWA launch.
- Cocos syntax transpilation is not an engine type-check, Editor import, scene preview or Creator build.

## Browser 50-stage edition

- Main entry: `index.html`; runtime: `src/web-game.js`; audio module: `src/audio.js`.
- 10 themed worlds, 5 stages per world, 5 route styles, world-specific trackside scenery, hazard silhouettes and handling grip.
- World/stage selection, three-car garage, three AI rivals, live race ranking, track minimap, keyboard steering, touch joystick/pedals/nitro, throttle/brake, collectible nitro boost, 3-lap race flow, pause/finish, local completion and best-time records.
- Audio is generated through the Web Audio API without downloaded audio assets or third-party runtime dependencies. AudioContext initializes after user interaction; mute/unmute is available in the HUD.
- No third-party runtime dependencies; progress and settings are stored locally in the browser. A versioned service worker (`mshin-arcade-v2`) caches the app shell and refreshes old caches so returning offline users receive updated gameplay after deployment.
- Automated Chromium tests exercise desktop and mobile menu-to-race flow and save `mshin-gameplay-desktop.png` and `mshin-gameplay-mobile.png` as the `mshin-gameplay-previews` workflow artifact. Full race completion, performance on low-end Android, touch gesture ergonomics, audio hardware compatibility, and art quality remain to be tuned.

## Cocos build feasibility and external gates

The inspected development runner has no Cocos Creator/Dashboard, Android SDK/NDK, `adb`, `sdkmanager`, `avdmanager` or Gradle. Official Creator 3.8 command-line publishing still requires an installed Creator GUI environment. Do not fabricate `.scene` files or claim Creator build/device QA based on Node tests.

External environment needed: a desktop with Cocos Creator 3.8.6 installed and opened, plus Android build dependencies and a physical device/emulator for APK/AAB and touch/orientation verification.

## Cloudflare boundary

`workers.js` exposes health/config and CORS preflight only. It is stateless, has no player-data persistence/leaderboard, and is not deployed or connected to the browser client. No R2/D1/KV/DO bindings or paid services are configured.
