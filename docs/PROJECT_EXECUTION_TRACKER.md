# Mshin — Project Execution Tracker

Last evidence refresh: 2026-10-30

## Repository and delivery state

- Default branch `main` contains the merged Cocos/game foundation at `f847457a04fdf82f654b61911b8b4b3a82c79fa1`.
- PR #1 is merged: https://github.com/pasoooir/Mshin/pull/1.
- GitHub Pages build and deploy completed successfully for that merge (run `41060146897`). The merged Pages version is the earlier single-stage browser prototype; it is not the Cocos build.
- Current browser expansion branch: `feat/web-50-stage-playable` (10 themed worlds, 50 selectable browser stages, local progress, touch/keyboard controls). It is not yet merged or published.
- No Cloudflare R2, D1, KV, Durable Objects, paid storage, or paid services are used.

## Evidence-based status

| Workstream | Status | Progress | Evidence / remaining acceptance gate |
|---|---:|---:|---|
| Repository foundation and stage catalog | 🟢 | 100% | 10 world themes and 50 deterministic stage definitions exist and pass data validation. Gameplay balancing remains tracked separately. |
| Portable driving/race core | 🟡 | 68% | Off-road handling, bounded frame-step timing and invalid-input safeguards have regression coverage; broader play balance remains. |
| Cocos Creator project/runtime integration | 🔴 | 20% | Project metadata and runtime scripts are in `assets/scripts/`; no Editor-created startup scene, engine type-check, Editor import, or Cocos preview/build has been verified. |
| Cocos world visuals and hazards | 🟡 | 38% | Theme-specific decorations, route generation and hazard drawing are implemented in source; Creator visual QA is outstanding. |
| Cocos menus, selection and HUD | 🟡 | 35% | Runtime-created UI/control code exists; Editor/device responsive QA is outstanding. |
| Browser playable edition | 🟡 | 70% | On `feat/web-50-stage-playable`: canvas runtime, 10 world palettes, 50 stage variants, stage/world selection, touch and keyboard controls, lap timer, pause/finish, hazards and local progress. Awaiting CI and browser interaction QA before merge/Pages publication. |
| Audio, animation and polish | ⬜ | 0% | Engine audio, particles, vehicle animation and final polish are not implemented. |
| Persistence and records | 🟡 | 65% | Browser localStorage and Cocos localStorage adapter source exist; offline/reload behavior and storage edge cases need browser/Editor verification. No server leaderboard. |
| Cloudflare Worker backend | 🟡 | 35% | Stateless health/config API and seven tests exist; not deployed or wired to a live game endpoint. |
| Portable automated tests | 🟢 | 100% | Main merge push run `41060146953` completed successfully; 39 portable tests passed on the merged Cocos/game foundation. Browser branch adds `node --check src/web-game.js`; new run is pending. |
| GitHub Pages delivery | 🟢 | 100% | Pages build and deploy jobs both succeeded in run `41060146897`. New 50-stage browser branch is not yet published. |
| Cocos Web build and browser QA | 🔴 | 0% | No Creator-generated Web output; requires Creator 3.8.6 and a real startup scene. Browser Canvas edition is a separate playable path, not a Cocos build. |
| Android APK/AAB and device QA | 🔴 | 0% | No APK/AAB; Android SDK/NDK/native toolchain and device testing are unavailable in the inspected runner. |

## CI evidence on main

- Game validation push run: https://github.com/pasoooir/Mshin/actions/runs/41060146953 — completed successfully.
- GitHub Pages build/deploy run: https://github.com/pasoooir/Mshin/actions/runs/41060146897 — build, upload and deploy jobs succeeded.
- The game validation workflow runs data validation, portable TypeScript build, Cocos syntax transpilation, Worker syntax, JavaScript syntax checks, and Node tests.
- Cocos syntax transpilation is not an engine type-check, Editor import, scene preview or Creator build.

## Browser 50-stage work in progress

- Branch: `feat/web-50-stage-playable`.
- `index.html` is now the world/stage selection and race UI.
- `src/web-game.js` implements a Canvas 2D race loop with 10 world palettes, 5 route patterns per world, themed trackside objects and hazards, steering, throttle/brake, lap completion, pause/finish screens and local best-time storage.
- CI adds a JavaScript syntax check for the new browser runtime.
- Remaining: CI pass, actual browser interaction test (desktop + touch viewport), visual fixes, then merge and verify Pages deployment.

## Cocos build feasibility and external gates

The inspected development runner has no Cocos Creator/Dashboard, Android SDK/NDK, `adb`, `sdkmanager`, `avdmanager` or Gradle. Official Creator 3.8 command-line publishing still requires an installed Creator GUI environment. Do not fabricate `.scene` files or claim Creator build/device QA based on Node tests.

External environment needed: a desktop with Cocos Creator 3.8.6 installed and opened, plus Android build dependencies and a physical device/emulator for APK/AAB and touch/orientation verification.

## Cloudflare boundary

`workers.js` exposes health/config and CORS preflight only. It is stateless, has no player-data persistence/leaderboard, and is not deployed or connected to the browser client. No R2/D1/KV/DO bindings or paid services are configured.
