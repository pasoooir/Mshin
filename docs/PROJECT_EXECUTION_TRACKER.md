# Mshin — Project Execution Tracker

Last evidence refresh: 2026-10-30

## Repository and delivery state

- Default branch `main` includes merge commit `2dcf18c46f16c8df45b77987f5f3f00f22e7be86` (PR #5), following PR #4.
- PR #1 (Cocos/game foundation), PR #2 (50-stage browser edition), PR #3 (Playwright browser QA), PR #4 (browser race audio and mute control), and PR #5 (visible car animation, race particles and screenshot QA) are merged.
- PR #4 adds dependency-free Web Audio engine tone, collision and finish effects, lazy AudioContext initialization after user interaction, and an accessible mute toggle.
- PR #4 validation passed: merged-main run `41064474829`; source-branch push and PR validation runs `41063447733` and `41063457438` also passed.
- PR #5 adds animated car details, world-accent lighting, exhaust trails, collision bursts and a finish celebration; it also verifies non-blank canvas pixels and captures desktop/mobile gameplay previews.
- PR #5 push and PR validation run `41065176095` and `41065195236` passed; screenshot artifact `mshin-gameplay-previews` is attached to PR run `41065195236` (expires 2026-11-06).
- Merged-main validation run `41065496716` passed. Pages build and deploy for the PR #5 merge commit succeeded in run `41065496240`.
- GitHub Pages build and deployment for merge commit `2dcf18c46f16c8df45b77987f5f3f00f22e7be86` succeeded: run `41065496240`.
- Main contains `index.html`, `src/web-game.js`, `src/audio.js`, and `tests/browser-smoke.mjs`; CI captures desktop and mobile gameplay screenshots.
- No Cloudflare R2, D1, KV, Durable Objects, paid storage, or paid services are used.

## Evidence-based status

| Workstream | Status | Progress | Evidence / remaining acceptance gate |
|---|---:|---:|---|
| Repository foundation and stage catalog | 🟢 | 100% | 10 world themes and 50 deterministic stage definitions exist and pass data validation. Gameplay balancing remains tracked separately. |
| Portable driving/race core | 🟡 | 68% | Off-road handling, bounded frame-step timing and invalid-input safeguards have regression coverage; broader play balance remains. |
| Cocos Creator project/runtime integration | 🔴 | 20% | Project metadata and runtime scripts are in `assets/scripts/`; no Editor-created startup scene, engine type-check, Editor import, or Cocos preview/build has been verified. |
| Cocos world visuals and hazards | 🟡 | 38% | Theme-specific decorations, route generation and hazard drawing are implemented in source; Creator visual QA is outstanding. |
| Cocos menus, selection and HUD | 🟡 | 35% | Runtime-created screens and controls exist; Editor/device responsive QA is outstanding. |
| Browser playable edition | 🟡 | 89% | Merged browser game has 10 world palettes, 50 stage variants, world/stage selection, touch/keyboard controls, lap timer, pause/finish, local progress, world-specific scenery, distinct hazard silhouettes, synthesized audio, animated vehicle details, exhaust trails and collision/finish particle effects. Full three-lap gameplay balance, device QA and art QA remain. |
| Browser automated QA | 🟢 | 100% | Playwright/Chromium CI verifies 10 worlds, five stages per world, Neon City stage 5 selection, race start, acceleration, non-blank canvas rendering, desktop/mobile screenshots, pause/resume, return to stage selection, mobile HUD/joystick/pedal sizing, sound mute/unmute state and no uncaught page errors. PR #5 push run `41065176095`, PR run `41065195236`, and merged-main validation run `41065496716` passed. |
| Audio, animation and polish | 🟡 | 48% | Browser engine tone, collision/finish audio, accessible mute toggle, animated vehicle wheels/body lighting, exhaust particles, collision bursts and finish celebration are merged and covered by Chromium smoke tests. More vehicle animation, persistent audio preference, additional environment effects and final polish remain. |
| Persistence and records | 🟡 | 65% | Browser localStorage and Cocos localStorage adapter source exist; offline/reload behavior and storage edge cases need additional verification. No server leaderboard. |
| Cloudflare Worker backend | 🟡 | 35% | Stateless health/config API and seven tests exist; not deployed or wired to a live game endpoint. |
| Portable automated tests | 🟢 | 100% | Merged-main validation run `41065496716` completed successfully, including Node tests, JS syntax checks, and Playwright Chromium desktop/mobile smoke tests with canvas pixel checks and screenshot capture. |
| GitHub Pages delivery | 🟢 | 100% | Pages build and deploy for merge commit `2dcf18c46f16c8df45b77987f5f3f00f22e7be86` both succeeded in run `41065496240`. |
| Cocos Web build and browser QA | 🔴 | 0% | No Creator-generated Web output; requires Creator 3.8.6 and a real startup scene. Browser Canvas edition is separate from a Cocos build. |
| Android APK/AAB and device QA | 🔴 | 0% | No APK/AAB; Android SDK/NDK/native toolchain and device testing are unavailable in the inspected runner. |

## CI and deployment evidence

- PR #4 merged: https://github.com/pasoooir/Mshin/pull/4 — audio and mute control.
- PR #5 merged: https://github.com/pasoooir/Mshin/pull/5 — animated car, particles, visible canvas assertions and screenshot artifacts; merge commit `2dcf18c46f16c8df45b77987f5f3f00f22e7be86`.
- PR #5 push validation: https://github.com/pasoooir/Mshin/actions/runs/41065176095 — success.
- PR #5 browser QA and screenshot artifact: https://github.com/pasoooir/Mshin/actions/runs/41065195236 — success.
- Merged-main validation: https://github.com/pasoooir/Mshin/actions/runs/41065496716 — success.
- PR #4 branch push validation: https://github.com/pasoooir/Mshin/actions/runs/41063447733 — success.
- PR #4 validation: https://github.com/pasoooir/Mshin/actions/runs/41063457438 — success.
- Pages build and deployment for PR #5 merge commit: https://github.com/pasoooir/Mshin/actions/runs/41065496240 — success.
- Browser smoke covers 10 worlds, five stages/world, race start, acceleration, non-blank rendered canvas, desktop/mobile screenshots, pause/resume, stage exit, mobile layout and sound toggle state.
- Cocos syntax transpilation is not an engine type-check, Editor import, scene preview or Creator build.

## Browser 50-stage edition

- Main entry: `index.html`; runtime: `src/web-game.js`; audio module: `src/audio.js`.
- 10 themed worlds, 5 stages per world, 5 route styles, world-specific trackside scenery, hazard silhouettes and handling grip.
- World/stage selection, keyboard steering, touch joystick/pedals, throttle/brake, 3-lap race flow, pause/finish, local completion and best-time records.
- Audio is generated through the Web Audio API without downloaded audio assets or third-party runtime dependencies. AudioContext initializes after user interaction; mute/unmute is available in the HUD.
- No third-party runtime dependencies; progress is stored locally in the browser.
- Automated Chromium tests exercise desktop and mobile menu-to-race flow and save `mshin-gameplay-desktop.png` and `mshin-gameplay-mobile.png` as the `mshin-gameplay-previews` workflow artifact. Full race completion, performance on low-end Android, touch gesture ergonomics, audio hardware compatibility, and art quality remain to be tuned.

## Cocos build feasibility and external gates

The inspected development runner has no Cocos Creator/Dashboard, Android SDK/NDK, `adb`, `sdkmanager`, `avdmanager` or Gradle. Official Creator 3.8 command-line publishing still requires an installed Creator GUI environment. Do not fabricate `.scene` files or claim Creator build/device QA based on Node tests.

External environment needed: a desktop with Cocos Creator 3.8.6 installed and opened, plus Android build dependencies and a physical device/emulator for APK/AAB and touch/orientation verification.

## Cloudflare boundary

`workers.js` exposes health/config and CORS preflight only. It is stateless, has no player-data persistence/leaderboard, and is not deployed or connected to the browser client. No R2/D1/KV/DO bindings or paid services are configured.
