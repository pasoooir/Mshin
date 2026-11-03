# Mshin Repository Enhancement Roadmap

**Reviewed:** 2026-11-03 after PRs #204, #205 and #208  
**Baseline:** `main` at `2d038c8dd084853211c6ea2b8ca93909a2ba9a9b`  
**Primary users:** mobile browsers (Android-first), with native Cocos Android delivery as the city visual target  
**Delivery:** GitHub Pages for browser racing/city experience; Cocos Creator 3.8.6 is the intended native city runtime.

## Mission

Improve the repository as a maintainable two-game product (racing + city simulation), not as a collection of disconnected PRs. Preserve working gameplay, avoid broad rewrites, and make every enhancement traceable to code, tests and acceptance evidence.

## Verified baseline

- **Current main:** `2d038c8dd084853211c6ea2b8ca93909a2ba9a9b`.
- **Merged city milestones:** PRs #188, #190, #192, #193, #195, #197, #199, #200, #201, #202 and #204 are present on main. They cover save migration/recovery, workforce and service capacity, resident wellbeing, zoning growth, service satisfaction, road-connected job assignment, pedestrian commute agents, traffic-aware pedestrian pace and congestion-related wellbeing.
- **Congestion regression follow-up:** PR #205 is merged; it isolates save telemetry validation from transient vehicle positions. Exact-head checks on #205 passed: `validate`, `browser-smoke`, road/zoning/traffic regression and population/employment regression.
- **Latest release:** Pages `build`, `deploy` and main `validate` passed on merge commit `2d038c8dd084853211c6ea2b8ca93909a2ba9a9b`. Main mobile browser smoke run `41647308147` is still running; city entry, mobile-only, three-lap finish and offline acceptance have not yet completed in that run.
- **Open PR inventory:** #209 is the documentation evidence refresh; #92 is a stale draft billboard branch and not an active release candidate.
- **PR #208:** 🟢 merged as `2d038c8dd084853211c6ea2b8ca93909a2ba9a9b`; exact-head `validate` passed. The native sample district includes distinct house, apartment, shop, factory, park, roads, sidewalks and street furniture. Main mobile browser smoke run `41647308147` is still running. The PR remains a blockout: final textures, Editor import, APK and physical Android acceptance are not verified.
- CI browser emulation does not certify physical Android devices or Cocos Creator Editor/Web build acceptance.

## Product priorities

### P0 — Protect mobile playability

- Keep mobile-only browser smoke as the required interactive browser gate for this phase.
- Cover portrait and landscape, compact Android viewports, safe-area insets, browser chrome/visual viewport changes and touch target sizes. VisualViewport resize and safe-area metadata are now covered by merged-main browser acceptance; physical notch testing remains open.
- Verify independent simultaneous pointers for steering, throttle, brake and nitro, including pointer cancel, lost capture, tab switch, pause, retry and orientation changes.
- Verify gyro permission, neutral calibration, sensitivity, direction and graceful fallback when sensors are unavailable.
- Set explicit performance budgets for frame time, long tasks, memory growth, asset decode and WebGL upload; test software WebGL and context restoration.
- Capture mobile screenshots and console/page errors as CI artifacts. Never label physical-device acceptance as complete based only on Playwright simulation.

### P1 — Stabilize the racing game

- Reconcile any newly opened racing PR against main before feature work. PR #92 remains a stale draft billboard branch (diverged/non-mergeable), not an active racing delivery. Current open PR inventory: #199 (road-network commuting) and stale draft #92; PR #196 and #198 are merged. PR #179 was merged as a documentation snapshot; this roadmap refresh supersedes its stale baseline. City budget/tax controls, accessible budget dialog and VisualViewport/safe-area behavior are merged in PRs #182, #185 and #186.
- Confirm the tenfold track-length and steering correction in PR #132 against current main behavior and automated evidence.
- Keep vehicle physics, input sampling, rendering and progression as separate testable domains.
- Verify a complete real race: countdown, driving, collisions, pickups, laps, finish, reward and persisted progress. Do not weaken finish/reward assertions to make smoke tests pass.
- Keep all runtime assets local or provide deterministic, non-blocking fallbacks; validate service-worker cache version and offline boot.

### P1 — Turn the city slice into a coherent simulation

- Treat the city as a separate product domain with its own state model, simulation clock, renderer, input and persistence adapter.
- Build in vertical slices: roads/connectivity → zoning → buildings and growth → population/jobs → utilities/services → traffic → budget/economy → save/load.
- Each system must have deterministic unit tests, integration tests and mobile browser acceptance for placement, simulation progression and persistence. Budget/tax controls and their accessible mobile dialog are accepted in PRs #182 and #185; versioned save migration/recovery is accepted in PR #188; workforce matching is accepted in PR #190; finite service capacity is accepted in PR #192; resident wellbeing integration is accepted in PR #193. Workforce-aware zoning growth is accepted in PR #195. Resident-weighted service satisfaction is accepted in PR #197. PRs #199–#204 now add road-network commuting, pedestrian commute agents, congestion-aware pedestrian movement and a bounded congestion wellbeing effect.
- Keep rendering and DOM/HUD work bounded; avoid rebuilding static layers or updating the HUD every animation frame.
- Prevent city changes from importing private racing modules and vice versa.

### P2 — Make architecture boundaries enforceable

- Establish explicit public interfaces for `racing`, `city` and `shared`.
- Extend dependency analysis to detect forbidden cross-domain imports, unresolved local imports, circular dependencies and oversized orchestration modules.
- Keep browser JavaScript and Cocos TypeScript as distinct runtimes until the authoritative production runtime and parity plan are explicit.
- Move one vertical slice at a time; separate file moves from behavior changes.
- Do not create empty placeholder modules or merge unrelated systems into giant engine files.

### P2 — Improve engineering quality and delivery

- Pin dependency versions with a committed lockfile and use reproducible CI installation (`npm ci`) where the lockfile is valid.
- Add formatting/lint policy only after measuring existing violations; do not mass-reformat unrelated code.
- Validate workflow YAML, action permissions, concurrency groups, timeout limits and artifact retention.
- Keep least-privilege workflow permissions and avoid exposing secrets to untrusted pull-request code.
- Add PR templates/checklists for scope, device matrix, tests, screenshots, offline behavior and rollback.
- Keep Pages deployment separate from validation; never deploy from an unverified feature branch. PR #198 aligns push/PR concurrency groups for browser smoke and validation.
- Keep Worker deployment optional and independent of the client release.

### P3 — Cocos Creator delivery gate

- Open the repository in Cocos Creator 3.8.6 and verify project import.
- Create/verify a real startup scene and serialized component references.
- Build the Web target from the Editor and test on Android browsers.
- Only then mark Cocos integration complete. Source syntax checks do not prove Editor import or a playable Cocos build.

## PR integration policy

1. Inspect each open PR's current diff, base/head refs, mergeability, reviews and checks.
2. Identify stacked PR dependencies; integrate in dependency order or rebase them onto the latest main.
3. Close or supersede duplicate/stale PRs only after verifying their changes are present elsewhere.
4. Require passing validation on the exact head commit to be merged.
5. Do not merge merely because a PR title matches a desired feature.
6. Keep `main` deployable; risky refactors stay behind isolated branches.

## Acceptance evidence template

For every feature, record:

- **User outcome:** what the player can do.
- **Scope:** exact runtime/domain and affected modules.
- **Unit evidence:** deterministic tests for rules and edge cases.
- **Integration evidence:** interaction between systems and persistence.
- **Mobile browser evidence:** viewport(s), orientation, touch sequence, screenshot and console status.
- **Performance evidence:** measured frame/long-task/upload budgets on representative hardware or documented CI emulation.
- **Release evidence:** exact commit, CI run and deployment run if published.
- **Known limitations:** physical device, Cocos Editor, backend or platform checks not yet completed.

## PR integration policy

1. Inspect each open PR's current diff, base/head refs, mergeability, reviews and checks.
2. Identify stacked PR dependencies; integrate in dependency order or rebase them onto the latest main.
3. Close or supersede duplicate/stale PRs only after verifying their changes are present elsewhere.
4. Require passing validation on the exact head commit to be merged.
5. Do not merge merely because a PR title matches a desired feature.
6. Keep `main` deployable; risky refactors stay behind isolated branches.

## Acceptance evidence template

For every feature, record:

- **User outcome:** what the player can do.
- **Scope:** exact runtime/domain and affected modules.
- **Unit evidence:** deterministic tests for rules and edge cases.
- **Integration evidence:** interaction between systems and persistence.
- **Mobile browser evidence:** viewport(s), orientation, touch sequence, screenshot and console status.
- **Performance evidence:** measured frame/long-task/upload budgets on representative hardware or documented CI emulation.
- **Release evidence:** exact commit, CI run and deployment run if published.
- **Known limitations:** physical device, Cocos Editor, backend or platform checks not yet completed.

## Current execution queue

| Priority | Work item | Status | Exit condition |
|---|---|---|---|
| P0 | Refresh evidence and reconcile PR inventory | 🟡 main at `52e8e22`; validate/build/deploy pass; main mobile smoke `41647308147` still running | Record final city-entry, mobile-only, rewarded three-lap and offline results; retain exact open-PR inventory |
| P0 | Mobile race + city acceptance matrix | 🟡 automated acceptance pending final main smoke; 🟡 physical-device gate | Exact-main browser run completes all mobile checks; separately verify physical Android safe areas, touch, thermal and performance |
| P1 | Racing stability and real-finish regression | 🟢 prior merged-main browser acceptance; current main smoke pending | Preserve full three-lap race, five-car standings, rewards, achievement persistence and offline launch; do not weaken finish assertions |
| P1 | City simulation vertical slices | 🟢 road commuting, pedestrian agents, traffic pace and bounded congestion wellbeing merged; 🟡 native Cocos visual slice PR #208 | Complete commute-time/economic feedback only with deterministic bounded model and tests; PR #208 is merged with source validation; Cocos Editor/scene/texture/APK and Android gates remain open |
| P1 | Native Cocos city visuals | 🟡 source blockout merged in PR #208 | Cocos Creator 3.8.6 Editor import, scene attachment, texture-backed assets, APK build and physical Android visual/performance acceptance |
| P2 | Enforce dependency boundaries | 🟢 implemented and CI-verified | Continue monitoring domain imports, unresolved paths, cycles and module size |
| P2 | Reproducible CI and release gates | 🟡 in progress | Keep lockfile-backed install, least privilege, exact-head checks, workflow concurrency and separate Pages deployment |
| P3 | Cocos Editor import and Web build | 🔴 not yet verified | Editor-generated Web build and Android execution; source syntax checks do not prove an Editor build |

## Non-goals for this phase

- No broad rewrite or destructive file moves.
- No forced merge of all open PRs.
- No desktop-browser gate that blocks mobile-first delivery.
- No claim of physical Android or Cocos Editor acceptance without actual device/Editor evidence.
- No production Worker deployment or paid infrastructure dependency without a product requirement.
