# Mshin — Project Execution Tracker

Last evidence refresh: 2026-10-30

## Repository and delivery state

- Default branch `main` current commit: `9ef737aca20f5f5b16a13db9604b3575c135617e`.
- PR #1 (Cocos/game foundation) and PR #2 (browser edition) are both merged.
- PR #2: https://github.com/pasoooir/Mshin/pull/2.
- GitHub Pages build/deploy for the 50-stage browser edition: run `41061000454` (deployment was still running at the time of this tracker update).
- Main now contains `index.html` and `src/web-game.js` for the 50-stage browser edition.
- No Cloudflare R2, D1, KV, Durable Objects, paid storage, or paid services are used.

## Evidence-based status

| Workstream | Status | Progress | Evidence / remaining acceptance gate |
|---|---:|---:|---|
| Repository foundation and stage catalog | 🟢 | 100% | 10 world themes and 50 deterministic stage definitions exist and pass data validation. Gameplay balancing remains tracked separately. |
| Portable driving/race core | 🟡 | 68% | Off-road handling, bounded frame-step timing and invalid-input safeguards have regression coverage; broader play balance remains. |
| Cocos Creator project/runtime integration | 🔴 | 20% | Project metadata and runtime scripts are in `assets/scripts/`; no Editor-created startup scene, engine type-check, Editor import, or Cocos preview/build has been verified. |
| Cocos world visuals and hazards | 🟡 | 38% | Theme-specific decorations, route generation and hazard drawing are implemented in source; Creator visual QA is outstanding. |
| Cocos menus, selection and HUD | 🟡 | 35% | Runtime-created screens and controls exist; Editor/device responsive QA is outstanding. |
| Browser playable edition | 🟡 | 75% | Merged to main: 10 world palettes, 50 stage variants, world/stage selection, touch and keyboard controls, lap timer, pause/finish, hazards and local progress. CI syntax check passes; actual browser interaction and visual QA remain. |
| Audio, animation and polish | ⬜ | 0% | Engine audio, particles, vehicle animation and final polish are not implemented. |
| Persistence and records | 🟡 | 65% | Browser localStorage and Cocos localStorage adapter source exist; offline/reload behavior and storage edge cases need browser/Editor verification. No server leaderboard. |
| Cloudflare Worker backend | 🟡 | 35% | Stateless health/config API and seven tests exist; not deployed or wired to a live game endpoint. |
| Portable automated tests | 🟢 | 100% | Main push run `41061000765` completed successfully, including `node --check src/web-game.js`; prior core suite passed 39 tests. This is not browser interaction or Cocos Editor QA. |
| GitHub Pages delivery | 🟡 | 90% | Pages build job succeeded in run `41061000454`; deploy job was still running when this tracker was refreshed. |
| Cocos Web build and browser QA | 🔴 | 0% | No Creator-generated Web output; requires Creator 3.8.6 and a real startup scene. The browser Canvas edition is a separate playable path, not a Cocos build. |
| Android APK/AAB and device QA | 🔴 | 0% | No APK/AAB; Android SDK/NDK/native toolchain and device testing are unavailable in the inspected runner. |

## CI evidence

- Main validation run: https://github.com/pasoooir/Mshin/actions/runs/41061000765 — completed successfully.
- Browser branch PR validation run: https://github.com/pasoooir/Mshin/actions/runs/41060941852 — completed successfully.
- Checks include data validation, portable TypeScript build, Cocos syntax transpilation, Worker syntax, JavaScript syntax checks including `src/web-game.js`, and Node tests.
- Cocos syntax transpilation is not an engine type-check, Editor import, scene preview or Creator build.

## Browser 50-stage edition

- Main entry: `index.html`; runtime: `src/web-game.js`.
- 10 themed worlds, 5 stage definitions per world, 5 route styles, world-specific scenery and hazards.
- World and stage selection, keyboard steering, touch joystick/pedals, throttle/brake, 3-lap race flow, pause/finish, local completion and best-time records.
- No third-party runtime dependencies; progress is stored locally in the browser.
- CI confirms JavaScript syntax. Browser interaction, mobile touch behavior, visual quality, and complete race-through testing remain outstanding.

## Cocos build feasibility and external gates

The inspected development runner has no Cocos Creator/Dashboard, Android SDK/NDK, `adb`, `sdkmanager`, `avdmanager` or Gradle. Official Creator 3.8 command-line publishing still requires an installed Creator GUI environment. Do not fabricate `.scene` files or claim Creator build/device QA based on Node tests.

External environment needed: a desktop with Cocos Creator 3.8.6 installed and opened, plus Android build dependencies and a physical device/emulator for APK/AAB and touch/orientation verification.

## Cloudflare boundary

`workers.js` exposes health/config and CORS preflight only. It is stateless, has no player-data persistence/leaderboard, and is not deployed or connected to the browser client. No R2/D1/KV/DO bindings or paid services are configured.
