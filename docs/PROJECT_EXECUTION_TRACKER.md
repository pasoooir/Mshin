# Mshin — Project Execution Tracker

Last evidence refresh: 2026-10-30

## Repository and delivery state

- Default branch `main` includes merge commit `a3871483482ccc0ca8141743ff1165854a9222ac` (PR #4).
- PR #1 (Cocos/game foundation), PR #2 (50-stage browser edition), PR #3 (Playwright browser QA), and PR #4 (browser race audio and mute control) are merged.
- PR #4 adds dependency-free Web Audio engine tone, collision and finish effects, lazy AudioContext initialization after user interaction, and an accessible mute toggle.
- Main validation for PR #4 passed: run `41064474829`; source-branch push and PR validation runs `41063447733` and `41063457438` also passed.
- GitHub Pages deployment for merge commit `a3871483482ccc0ca8141743ff1165854a9222ac` was triggered as run `41064473937`; it was still in progress at the time of this tracker refresh. The previous deployment run `41061429362` succeeded.
- Main contains `index.html`, `src/web-game.js`, `src/audio.js`, and `tests/browser-smoke.mjs`.
- No Cloudflare R2, D1, KV, Durable Objects, paid storage, or paid services are used.

## Evidence-based status

| Workstream | Status | Progress | Evidence / remaining acceptance gate |
|---|---:|---:|---|
| Repository foundation and stage catalog | 🟢 | 100% | 10 world themes and 50 deterministic stage definitions exist and pass data validation. Gameplay balancing remains tracked separately. |
| Portable driving/race core | 🟡 | 68% | Off-road handling, bounded frame-step timing and invalid-input safeguards have regression coverage; broader play balance remains. |
| Cocos Creator project/runtime integration | 🔴 | 20% | Project metadata and runtime scripts are in `assets/scripts/`; no Editor-created startup scene, engine type-check, Editor import, or Cocos preview/build has been verified. |
| Cocos world visuals and hazards | 🟡 | 38% | Theme-specific decorations, route generation and hazard drawing are implemented in source; Creator visual QA is outstanding. |
| Cocos menus, selection and HUD | 🟡 | 35% | Runtime-created screens and controls exist; Editor/device responsive QA is outstanding. |
| Browser playable edition | 🟡 | 86% | Merged browser game has 10 world palettes, 50 stage variants, world/stage selection, touch/keyboard controls, lap timer, pause/finish, local progress, world-specific scenery, distinct hazard silhouettes and synthesized audio effects with mute control. Full three-lap gameplay balance, audio-device QA and art QA remain. |
| Browser automated QA | 🟢 | 100% | Playwright/Chromium CI verifies 10 worlds, five stages per world, Neon City stage 5 selection, race start, acceleration, pause/resume, return to stage selection, mobile HUD/joystick/pedal sizing, sound mute/unmute state and no uncaught page errors. PR #4 push run `41063447733`, PR run `41063457438`, and merged-main validation run `41064474829` passed. |
| Audio, animation and polish | 🟡 | 30% | Browser engine tone, collision/finish effects and accessible mute toggle are merged and covered by browser smoke tests. Particles, vehicle animation, persistent audio preference and final polish remain. |
| Persistence and records | 🟡 | 65% | Browser localStorage and Cocos localStorage adapter source exist; offline/reload behavior and storage edge cases need additional verification. No server leaderboard. |
| Cloudflare Worker backend | 🟡 | 35% | Stateless health/config API and seven tests exist; not deployed or wired to a live game endpoint. |
| Portable automated tests | 🟢 | 100% | Merged-main validation run `41064474829` completed successfully, including Node tests, JS syntax checks, and Playwright Chromium desktop/mobile smoke tests. |
| GitHub Pages delivery | 🟡 | 95% | Pages build/deploy was triggered for merge commit `a3871483482ccc0ca8141743ff1165854a9222ac` as run `41064473937`; deployment was still in progress at tracker refresh. Previous Pages deployment run `41061429362` succeeded. |
| Cocos Web build and browser QA | 🔴 | 0% | No Creator-generated Web output; requires Creator 3.8.6 and a real startup scene. Browser Canvas edition is separate from a Cocos build. |
| Android APK/AAB and device QA | 🔴 | 0% | No APK/AAB; Android SDK/NDK/native toolchain and device testing are unavailable in the inspected runner. |

## CI and deployment evidence

- PR #4 merged: https://github.com/pasoooir/Mshin/pull/4 — merge commit `a3871483482ccc0ca8141743ff1165854a9222ac`.
- Merged-main validation: https://github.com/pasoooir/Mshin/actions/runs/41064474829 — success.
- PR #4 branch push validation: https://github.com/pasoooir/Mshin/actions/runs/41063447733 — success.
- PR #4 validation: https://github.com/pasoooir/Mshin/actions/runs/41063457438 — success.
- Pages deployment for merge commit: https://github.com/pasoooir/Mshin/actions/runs/41064473937 — in progress at last check.
- Previous successful Pages deployment: https://github.com/pasoooir/Mshin/actions/runs/41061429362.
- Browser smoke covers 10 worlds, five stages/world, race start, acceleration, pause/resume, stage exit, mobile layout and sound toggle state.
- Cocos syntax transpilation is not an engine type-check, Editor import, scene preview or Creator build.

## Browser 50-stage edition

- Main entry: `index.html`; runtime: `src/web-game.js`; audio module: `src/audio.js`.
- 10 themed worlds, 5 stages per world, 5 route styles, world-specific trackside scenery, hazard silhouettes and handling grip.
- World/stage selection, keyboard steering, touch joystick/pedals, throttle/brake, 3-lap race flow, pause/finish, local completion and best-time records.
- Audio is generated through the Web Audio API without downloaded audio assets or third-party runtime dependencies. AudioContext initializes after user interaction; mute/unmute is available in the HUD.
- No third-party runtime dependencies; progress is stored locally in the browser.
- Automated Chromium tests exercise desktop and mobile menu-to-race flow. Full race completion, performance on low-end Android, touch gesture ergonomics, audio hardware compatibility, and art quality remain to be tuned.

## Cocos build feasibility and external gates

The inspected development runner has no Cocos Creator/Dashboard, Android SDK/NDK, `adb`, `sdkmanager`, `avdmanager` or Gradle. Official Creator 3.8 command-line publishing still requires an installed Creator GUI environment. Do not fabricate `.scene` files or claim Creator build/device QA based on Node tests.

External environment needed: a desktop with Cocos Creator 3.8.6 installed and opened, plus Android build dependencies and a physical device/emulator for APK/AAB and touch/orientation verification.

## Cloudflare boundary

`workers.js` exposes health/config and CORS preflight only. It is stateless, has no player-data persistence/leaderboard, and is not deployed or connected to the browser client. No R2/D1/KV/DO bindings or paid services are configured.
