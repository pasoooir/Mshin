# Mshin — Project Execution Tracker

Last evidence refresh: 2026-10-30
Working branch: `feat/game-foundation-and-stage-art`
Baseline head: `1f1f303f2eac05e46e85fd4827463771b21d8720`
PR: [#1](https://github.com/pasoooir/Mshin/pull/1) — open, not merged.

## Status and progress

| Workstream | Status | Progress | Acceptance evidence / remaining gate |
|---|---:|---:|---|
| Repository foundation and 10-world/50-stage catalog | 🟡 | 55% | 50 deterministic definitions and 10 themes validate; all stages still need actual Cocos playtesting and balance. |
| Portable driving/race core | 🟡 | 60% | Engine-independent TypeScript builds and unit tests pass; adapter/race behavior needs engine tests. |
| Cocos Creator project/runtime integration | 🔴 | 20% | Project metadata and four Cocos scripts exist; no Editor-created scene, engine type-check, import, preview or runtime evidence. |
| Visual environments and hazards | 🟡 | 30% | Procedural track and theme decoration source exists; no Creator visual QA. |
| Menus, world/stage selection and HUD | 🟡 | 35% | Runtime-created screens and controls exist; responsive layout and interactions need Editor/device testing. |
| Audio, animation and polish | ⬜ | 0% | Motor/brake/impact audio, particles and motion polish not implemented. |
| Persistence and records | 🟡 | 35% | Local progress/best-time source exists; persistence needs engine/runtime verification. |
| Portable automated tests | 🟢 | 100% | Latest recorded push and PR Actions passed; 21 Node tests passed in the prior run. This does not prove Cocos runtime correctness. |
| Cocos Web build and browser QA | 🔴 | 0% | No real Cocos Web output; requires Creator 3.8.6 and a valid startup scene. |
| Android APK/AAB and device QA | 🔴 | 0% | No APK/AAB; Android SDK/NDK and native build environment absent in inspected runner. |
| CI/CD and delivery | 🟡 | 30% | Portable validation exists; Editor-backed builds and artifact publishing remain. |

## GitHub Actions evidence (baseline head)
- Push run [41056217464](https://github.com/pasoooir/Mshin/actions/runs/41056217464): completed successfully.
- PR run [41056224354](https://github.com/pasoooir/Mshin/actions/runs/41056224354): completed successfully.
- Both ran data validation, portable TypeScript compilation, Cocos-script syntax transpilation, JavaScript syntax checks and Node tests.
- `transpileModule` is syntax-only; it is not an engine type-check, scene import, Editor preview or Cocos build.

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

No `.scene` is fabricated. No Cocos build, APK/AAB, device test or Pages deployment is claimed. No merge, release, secret change, payment or Cloudflare R2 use.