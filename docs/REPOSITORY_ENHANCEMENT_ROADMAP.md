# Mshin Repository Enhancement Roadmap

**Reviewed:** 2026-11-03 after PRs #204, #205, #208, #209, #211, #217 and #221  
**Baseline:** `main` at `b586574af4d13a7836fb6ccd63e7d9df3f8a5955`  
**Primary users:** mobile browsers (Android-first), with native Cocos Android delivery as the city visual target  
**Delivery:** GitHub Pages for browser racing/city experience; Cocos Creator 3.8.6 is the intended native city runtime.

## Mission

Improve the repository as a maintainable two-game product (racing + city simulation), not as a collection of disconnected PRs. Preserve working gameplay, avoid broad rewrites, and make every enhancement traceable to code, tests and acceptance evidence.

## Verified baseline

- **Current main:** `b586574af4d13a7836fb6ccd63e7d9df3f8a5955`.
- **Merged city milestones:** PRs #188, #190, #192, #193, #195, #197, #199, #200, #201, #202, #204 and #211 are present on main. They cover save migration/recovery, workforce and service capacity, resident wellbeing, zoning growth, service satisfaction, road-connected job assignment, pedestrian commute agents, traffic-aware pedestrian pace and congestion-related wellbeing.
- **Congestion regression follow-up:** PR #205 is merged; it isolates save telemetry validation from transient vehicle positions. Exact-head checks on #205 passed: `validate`, `browser-smoke`, road/zoning/traffic regression and population/employment regression.
- **Latest main delivery:** PR #209 documentation refresh 🟢 merged at `e1e0b5aac47258d093a2cfd0be5fe806d275dab2` on 2026-11-03 15:06 UTC. PR #217 and #221 subsequently merged; current main is `b586574af4d13a7836fb6ccd63e7d9df3f8a5955`. Main `validate` (`41664637302`), mobile browser smoke (`41664637171`) and Pages build/deploy (`41664635944`) were running at this evidence snapshot.
- **PR #211 — Congestion-driven business productivity:** 🟢 merged as `b586574af4d13a7836fb6ccd63e7d9df3f8a5955`; exact-head validation, city regression suites and mobile browser acceptance all passed (runs `41648207345`, `41648207411`, `41648207413`, `41648207450`, `41648207532`, `41648207541`, `41648207909`). Commercial/industrial productivity is reduced by a deterministic 0–15% proxy; residential tax and public funding are unchanged; metrics are persisted and shown in the mobile budget panel.
- **PR #209:** documentation refresh remains open while its baseline/evidence is reconciled with #211; exact-head validation and browser smoke passed on the previous docs head, but rerun after this update.
- **PR #209 — Documentation evidence refresh:** 🟢 merged; exact-head validation run `41657282760` and mobile browser smoke run `41657282312` passed.
- **PR #217 — Native building construction/upgrade lifecycle:** 🟢 merged in mainline commit `bc77aeaec62ea65b4620388cd3b7ec5674b165d9`; deterministic lifecycle core and unit tests included. Placement/economy/save/UI remain separate work.
- **PR #221 — Architecture audit fix:** 🟢 merged as `b586574af4d13a7836fb6ccd63e7d9df3f8a5955`; NodeNext `.js` specifiers resolve to `.ts` source and native city scripts are classified in the city domain. Exact-head validation run `41662862217` and mobile browser smoke `41662862281` passed.
- **PR #222 — Native touch building placement:** 🟡 active; single-touch ownership, ground-ray validation, grid snapping and geometry tests included. Scene/prefab/Editor/device gates remain open.
- **PR #223 — Procedural texture raster validation:** 🟡 active; workflow, validator and artifact publication prepared; Cocos material integration remains open.
- **PR #218 and #212:** older stacked branches superseded by rebased successors #222 and #223.
- **Open PR inventory:** #222 touch placement, #223 texture raster validation and stale draft #92.
- **PR #208:** 🟢 merged as `2d038c8dd084853211c6ea2b8ca93909a2ba9a9b`; exact-head `validate` passed. The native sample district includes distinct house, apartment, shop, factory, park, roads, sidewalks and street furniture. Main mobile browser smoke run `41647308147` passed. The PR remains a blockout: final textures, Editor import, APK and physical Android acceptance are not verified.
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

- Reconcile any newly opened racing PR against main before feature work. PR #92 remains a stale draft billboard branch (diverged/non-mergeable), not an active racing delivery. Current open PR inventory: #209 documentation refresh and stale draft #92; PRs #196, #198 and #211 are merged. PR #179 was merged as a documentation snapshot; this roadmap refresh supersedes its stale baseline. City budget/tax controls, accessible budget dialog and VisualViewport/safe-area behavior are merged in PRs #182, #185 and #186.
- Confirm the tenfold track-length and steering correction in PR #132 against current main behavior and automated evidence.
- Keep vehicle physics, input sampling, rendering and progression as separate testable domains.
- Verify a complete real race: countdown, driving, collisions, pickups, laps, finish, reward and persisted progress. Do not weaken finish/reward assertions to make smoke tests pass.
- Keep all runtime assets local or provide deterministic, non-blocking fallbacks; validate service-worker cache version and offline boot.

### P1 — Turn the city slice into a coherent simulation

- Treat the city as a separate product domain with its own state model, simulation clock, renderer, input and persistence adapter.
- Build in vertical slices: roads/connectivity → zoning → buildings and growth → population/jobs → utilities/services → traffic → budget/economy → save/load.
- Each system must have deterministic unit tests, integration tests and mobile browser acceptance for placement, simulation progression and persistence. Budget/tax controls and their accessible mobile dialog are accepted in PRs #182 and #185; versioned save migration/recovery is accepted in PR #188; workforce matching is accepted in PR #190; finite service capacity is accepted in PR #192; resident wellbeing integration is accepted in PR #193. Workforce-aware zoning growth is accepted in PR #195. Resident-weighted service satisfaction is accepted in PR #197. PRs #199–#204 add road-network commuting, pedestrian commute agents, congestion-aware pedestrian movement and a bounded congestion wellbeing effect; PR #211 adds a bounded congestion-to-business-productivity feedback; PR #217 adds the native Cocos building lifecycle; PR #222 adds touch placement.
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
| P0 | Refresh evidence and reconcile PR inventory | 🟡 main at `ceaec137`; PR #211 merged; PR #209 docs checks passed on prior head and require rerun after evidence refresh | Record post-#211 main validate/build/deploy/browser results and exact open-PR inventory |
| P0 | Mobile race + city acceptance matrix | 🟢 main browser acceptance `41647308147`; 🟡 physical-device gate | Exact-main browser run completes all mobile checks; separately verify physical Android safe areas, touch, thermal and performance |
| P1 | Racing stability and real-finish regression | 🟢 main browser smoke `41647308147` | Preserve full three-lap race, five-car standings, rewards, achievement persistence and offline launch; do not weaken finish assertions |
| P1 | City simulation vertical slices | 🟢 road commuting, pedestrian agents, traffic pace, bounded congestion wellbeing and business productivity feedback merged; 🟡 native Cocos visual slice | Continue with measured commute-time/economic tuning only when deterministic and bounded; Cocos Editor/scene/texture/APK and Android gates remain open |
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
