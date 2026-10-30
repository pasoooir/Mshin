# Mshin — Project Execution Tracker

Last evidence refresh: 2026-10-30
Working branch: `feat/game-foundation-and-stage-art`
Validated source head: `50f3564bf0bca17a909d67afb254945524d9ceec`
PR: [#1](https://github.com/pasoooir/Mshin/pull/1) — open, draft, not merged.

## Status and progress

| Workstream | Status | Progress | Acceptance evidence / remaining gate |
|---|---:|---:|---|
| Repository foundation and 10-world/50-stage catalog | 🟡 | 55% | 50 deterministic definitions and 10 themes validate; all stages still need actual Cocos playtesting and balance. |
| Portable driving/race core | 🟡 | 60% | Engine-independent TypeScript builds and unit tests pass; adapter/race behavior needs engine tests. |
| Cocos Creator project/runtime integration | 🔴 | 20% | Project metadata and four Cocos scripts exist; no Editor-created scene, engine type-check, import, preview or runtime evidence. |
| Visual environments and hazards | 🟡 | 38% | Per-world hazard silhouettes (9 hazard families), procedural track/decor and generated stage-track thumbnails exist; no Creator visual QA. |
| Menus, world/stage selection and HUD | 🟡 | 35% | Runtime-created screens and controls exist; responsive layout and interactions need Editor/device testing. |
| Audio, animation and polish | ⬜ | 0% | Motor/brake/impact audio, particles and motion polish not implemented. |
| Persistence and records | 🟡 | 55% | Pure progress domain logic now normalizes corrupt/invalid records, deduplicates completions, validates stage/time inputs and preserves best times; Cocos localStorage adapter still needs Editor/runtime verification. |
| Cloudflare Worker backend | 🟡 | 35% | Stateless `workers.js` API provides health/config, exact-origin CORS and 7 tests; not deployed or connected to a live game client. No R2/D1/KV or paid storage. |
| Portable automated tests | 🟢 | 100% | Latest push and PR Actions passed; **36 Node tests passed, 0 failed** (including 8 progress-domain tests and 7 Worker tests). This does not prove Cocos runtime correctness. |
| Cocos Web build and browser QA | 🔴 | 0% | No real Cocos Web output; requires Creator 3.8.6 and a valid startup scene. |
| Android APK/AAB and device QA | 🔴 | 0% | No APK/AAB; Android SDK/NDK and native build environment absent in inspected runner. |
| CI/CD and delivery | 🟡 | 35% | Portable validation includes Worker syntax/API tests and progress-domain tests; Editor-backed builds and artifact publishing remain. |

## GitHub Actions evidence (validated source head)

- Push run [41058258207](https://github.com/pasoooir/Mshin/actions/runs/41058258207): completed successfully for `50f3564b`.
- PR run [41058267989](https://github.com/pasoooir/Mshin/actions/runs/41058267989): completed successfully for `50f3564b`.
- PR job log reports **36 tests passed, 0 failed**.
- Checks include data validation, portable TypeScript compilation, Cocos-script syntax transpilation, Worker syntax validation, JavaScript syntax checks and Node tests.
- `transpileModule` is syntax-only; it is not an engine type-check, scene import, Editor preview or Cocos build.

## Recent persistence hardening

- Added engine-independent `src/progress.ts` so player-progress rules can be unit-tested without importing Cocos.
- Invalid save shapes, duplicate/out-of-range completion IDs, malformed best-time maps and non-finite/non-positive times are rejected or normalized safely.
- Completing a stage is idempotent; only a faster valid time replaces a stored best time.
- All 50 stages remain selectable by design; completion and best-time tracking are independent.
- The Cocos adapter catches localStorage read/write failures so a storage quota or unavailable storage does not crash the race flow.

## Cloudflare Worker boundary

- Entry point: `workers.js`; Wrangler config: `wrangler.toml`.
- Implemented routes: `GET /api/v1/health`, `GET /api/v1/config`, and CORS preflight.
- The Worker is stateless. Player progress remains local-first; no leaderboard or server persistence is claimed.
- No R2, D1, KV, Durable Objects, storage bindings, secrets or paid services are configured.
- Worker deployment and production endpoint wiring have not been performed.

## Cocos build feasibility

The official Creator 3.8 command-line publishing guide documents `CocosCreator --project ... --build ...` and explicitly says command-line publishing still needs a GUI environment. A standard headless Ubuntu runner is therefore not a valid Editor-build substitute. A self-hosted Windows/macOS runner with Creator 3.8.6 installed and an interactive desktop session is plausible, but has not been provisioned or verified.

Official references:
- [Cocos Creator 3.8 command-line publishing](https://docs.cocos.com/creator/3.8/manual/en/editor/publish/publish-in-command-line.html)
- [Official Creator download page and 3.8.6 release notes](https://www.cocos.com/creator-download)

## External dependencies

1. Windows 10/11 or macOS machine with Cocos Creator 3.8.6 Editor installed and opened; import project, create/save a real startup scene, and verify preview.
2. Interactive desktop session for Creator CLI build.
3. Android SDK, NDK, Java/native build dependencies configured in Creator; physical Android device or emulator for landscape/touch QA.
4. Browser automation against an actual Cocos Web build.
5. After Worker deployment is explicitly approved, configure and verify its URL in the game client. No live endpoint exists yet.

No `.scene` is fabricated. No Cocos build, APK/AAB, device test, Worker deployment or Pages deployment is claimed. No merge, release, secret change, payment or Cloudflare R2 use.
