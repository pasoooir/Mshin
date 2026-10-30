# Mshin — Project Execution Tracker

Last evidence refresh: 2026-10-30

## Repository and delivery state

- Default branch `main` current code commit: `9ef737aca20f5f5b16a13db9604b3575c135617e`; browser test infrastructure merged at `e70fd335df1fb88af90f25c2492dc0adc1841452`.
- PR #1 (Cocos/game foundation), PR #2 (50-stage browser edition), and PR #3 (Playwright browser QA) are merged.
- PR #3: https://github.com/pasoooir/Mshin/pull/3.
- GitHub Pages build for the 50-stage browser edition succeeded in run `41061123100`; deployment was in progress at the last check.
- Main contains `index.html` and `src/web-game.js` for the 50-stage browser edition, plus `tests/browser-smoke.mjs`.
- No Cloudflare R2, D1, KV, Durable Objects, paid storage, or paid services are used.

## Evidence-based status

| Workstream | Status | Progress | Evidence / remaining acceptance gate |
|---|---:|---:|---|
| Repository foundation and stage catalog | 🟢 | 100% | 10 world themes and 50 deterministic stage definitions exist and pass data validation. Gameplay balancing remains tracked separately. |
| Portable driving/race core | 🟡 | 68% | Off-road handling, bounded frame-step timing and invalid-input safeguards have regression coverage; broader play balance remains. |
| Cocos Creator project/runtime integration | 🔴 | 20% | Project metadata and runtime scripts are in `assets/scripts/`; no Editor-created startup scene, engine type-check, Editor import, or Cocos preview/build has been verified. |
| Cocos world visuals and hazards | 🟡 | 38% | Theme-specific decorations, route generation and hazard drawing are implemented in source; Creator visual QA is outstanding. |
| Cocos menus, selection and HUD | 🟡 | 35% | Runtime-created screens and controls exist; Editor/device responsive QA is outstanding. |
| Browser playable edition | 🟡 | 82% | Merged to main: 10 world palettes, 50 stage variants, world/stage selection, touch and keyboard controls, lap timer, pause/finish, hazards and local progress. Chromium smoke tests pass on desktop and mobile; full three-lap gameplay balance and visual QA remain. |
| Browser automated QA | 🟢 | 100% | Playwright/Chromium CI verifies 10 worlds, five stages per world, Neon City stage 5 selection, race start, acceleration, pause/resume, return to stage selection, mobile HUD/joystick/pedal sizing, and no uncaught page errors. Push run `41061168615` and PR run `41061182021` passed. |
| Audio, animation and polish | ⬜ | 0% | Engine audio, particles, vehicle animation and final polish are not implemented. |
| Persistence and records | 🟡 | 65% | Browser localStorage and Cocos localStorage adapter source exist; offline/reload behavior and storage edge cases need additional verification. No server leaderboard. |
| Cloudflare Worker backend | 🟡 | 35% | Stateless health/config API and seven tests exist; not deployed or wired to a live game endpoint. |
| Portable automated tests | 🟢 | 100% | Main validation run `41061000765` passed including browser runtime syntax; Playwright browser tests passed in `41061168615` and `41061182021`. |
| GitHub Pages delivery | 🟡 | 95% | Pages build job succeeded in run `41061123100`; deploy job was still running at the last check. |
| Cocos Web build and browser QA | 🔴 | 0% | No Creator-generated Web output; requires Creator 3.8.6 and a real startup scene. Browser Canvas edition is a separate playable path, not a Cocos build. |
| Android APK/AAB and device QA | 🔴 | 0% | No APK/AAB; Android SDK/NDK/native toolchain and device testing are unavailable in the inspected runner. |

## CI evidence

- Main game validation: https://github.com/pasoooir/Mshin/actions/runs/41061000765 — successful.
- Browser branch push validation: https://github.com/pasoooir/Mshin/actions/runs/41060904726 — successful.
- Browser PR validation: https://github.com/pasoooir/Mshin/actions/runs/41060941852 — successful.
- Browser Playwright push run: https://github.com/pasoooir/Mshin/actions/runs/41061168615 — successful.
- Browser Playwright PR run: https://github.com/pasoooir/Mshin/actions/runs/41061182021 — successful.
- Playwright output: `Browser smoke passed: 10 worlds, 5 stages/world, race start, acceleration, pause/resume, stage exit, and mobile layout.`
- Checks include data validation, portable TypeScript build, Cocos syntax transpilation, Worker syntax, JavaScript syntax, Node tests, and Chromium desktop/mobile smoke tests.
- Cocos syntax transpilation is not an engine type-check, Editor import, scene preview or Creator build.

## Browser 50-stage edition

- Main entry: `index.html`; runtime: `src/web-game.js`.
- 10 themed worlds, 5 stage definitions per world, 5 route styles, world-specific scenery and hazards.
- World and stage selection, keyboard steering, touch joystick/pedals, throttle/brake, 3-lap race flow, pause/finish, local completion and best-time records.
- No third-party runtime dependencies; progress is stored locally in the browser.
- Automated Chromium tests exercise the main menu-to-race flow on desktop and mobile. Full race completion, performance on low-end Android, touch gesture ergonomics, and art quality remain to be tuned.

## Cocos build feasibility and external gates

The inspected development runner has no Cocos Creator/Dashboard, Android SDK/NDK, `adb`, `sdkmanager`, `avdmanager` or Gradle. Official Creator 3.8 command-line publishing still requires an installed Creator GUI environment. Do not fabricate `.scene` files or claim Creator build/device QA based on Node tests.

External environment needed: a desktop with Cocos Creator 3.8.6 installed and opened, plus Android build dependencies and a physical device/emulator for APK/AAB and touch/orientation verification.

## Cloudflare boundary

`workers.js` exposes health/config and CORS preflight only. It is stateless, has no player-data persistence/leaderboard, and is not deployed or connected to the browser client. No R2/D1/KV/DO bindings or paid services are configured.
