# Mshin Repository Enhancement Roadmap

**Reviewed:** 2026-11-03 after PR #193  
**Baseline:** `main` at `828b8705dfb51143e7d56f254a5c7464fb922a64`  
**Primary users:** mobile browsers (Android-first)  
**Delivery:** GitHub Pages; optional Cloudflare Worker remains separate from the playable client.

## Mission

Improve the repository as a maintainable two-game product (racing + city simulation), not as a collection of disconnected PRs. Preserve working gameplay, avoid broad rewrites, and make every enhancement traceable to code, tests and acceptance evidence.

## Verified baseline

- Main contains separate browser racing and city entry points, portable TypeScript/Cocos source, a service worker, local assets, data validation, unit tests and GitHub Actions.
- Latest merged-main mobile browser evidence: [run 41614496592](https://github.com/pasoooir/Mshin/actions/runs/41614496592) — success on bb2eea0; includes immersive city entry, city budget/viewport checks, mobile-only input checks, a complete three-lap rewarded race and offline PWA acceptance.
- Latest merged-main portable validation: [run 41614496731](https://github.com/pasoooir/Mshin/actions/runs/41614496731) — success; all validation stages and Node tests passed.
- Latest merged-main GitHub Pages deployment: [run 41614495844](https://github.com/pasoooir/Mshin/actions/runs/41614495844) — build and deploy succeeded for bb2eea0.
- PR #176 is merged as 616be0381f3eeda0c8923b288e33467361493a5d; it adds portrait-mobile full-race acceptance, compact finish-screen layout, screenshot evidence and offline acceptance. PR #175 was closed as a superseded duplicate.
- PR #178 merged as c19e7273f4ec5bb9bb583cda58038a749872734f; city entry requests fullscreen before landscape lock, retries on the first trusted touch/click, and retains a portrait fallback. Mobile city smoke and portable validation passed.
- PR #177 merged as b55ba56bed2c2ebdb08ba0707df9a786a5fa0a72; deterministic bounded pedestrians follow road tiles, synchronize to residential occupancy, migrate old saves and render through instanced 3D meshes.
- PR #180 merged as f3e26f981c09ea57afb5395423d53a55471115a3; adds home-demolition pedestrian reassignment regression coverage.
- PR #182 merged as 7e6b79d94c8a132d71079e89955f8de019922c6d; adds deterministic budget/economy, bounded sector tax rates, persisted tax policy, maintenance and tax-pressure effects on happiness. Merged-main validation, mobile smoke and Pages deployment passed.
- PR #185 merged as a77d2f0b3951f169509759d99aeaa5f0fe555af6; hardens the budget dialog with touch-sized controls, safe scrolling, focus restoration, Escape dismissal and keyboard focus trapping.
- PR #186 merged as bb2eea0ba62fdc55a59a31584cb9342ca29ff4df; race and city canvases follow VisualViewport resize events, preserve software-landscape dimensions and respect city budget-dialog safe-area insets.
- Exact-head checks for PR #185 passed (runs 41610689215 and 41610689302); exact-head portable validation and mobile smoke for PR #186 passed (runs 41613453589 and 41613453754).
- Main-after-merge validation, mobile browser acceptance and Pages deployment passed (runs 41614496731, 41614496592 and 41614495844).
- PRs #181, #183 and #184 were closed as superseded duplicates of PR #182. PR #179 was a historical documentation snapshot; this refresh supersedes its baseline.
- Mobile gameplay preview artifact: [mshin-mobile-gameplay-previews](https://github.com/pasoooir/Mshin/actions/runs/41614496592/artifacts/13216086671).
- CI success is not equivalent to physical Android-device certification or Cocos Creator Editor/Web build acceptance.


- PR #188 merged as `1b2c99a6a8669dff42bde3768726df5d08106b3d`; versioned city-save migration, backup/recovery and offline precache acceptance.
- PR #190 merged as `5f20315e9c267aeefdf77f8bb5cda27d8da0c22f`; deterministic workforce matching, job capacity, employment, unemployment and vacancies.
- PR #192 merged as `98f152105c7716c6a0a323a4f680129070152363`; finite utility/public-service capacity, demand coverage and per-building satisfaction telemetry.
- Post-PR #192 main validation and Pages build/deploy succeeded in run `41623889163`; main browser-smoke is still in progress.
- PR #193 (resident wellbeing integration) and PR #195 (workforce-aware zoning growth) are open; their checks are tracked in the execution tracker. Neither is accepted until all exact-head mobile/browser checks pass.

- PR #188 merged as `1b2c99a6a8669dff42bde3768726df5d08106b3d`; versioned city-save migration, backup/recovery and offline precache acceptance.
- PR #190 merged as `5f20315e9c267aeefdf77f8bb5cda27d8da0c22f`; deterministic workforce matching, job capacity, employment, unemployment and vacancies.
- PR #192 merged as `98f152105c7716c6a0a323a4f680129070152363`; finite utility/public-service capacity, demand coverage and per-building satisfaction telemetry.
- PR #193 merged as `828b8705dfb51143e7d56f254a5c7464fb922a64`; resident wellbeing now reflects unemployment and service coverage/capacity metrics are exposed in city stats.
- Main validation/build/deploy succeeded in run `41624866155`; browser smoke is still running at the time of this refresh.
- PR #195 remains open; exact-head validation, employment and zoning regressions, and mobile viewport acceptance pass; mobile rewarded race/offline browser smoke is still running.

## Product priorities

### P0 — Protect mobile playability

- Keep mobile-only browser smoke as the required interactive browser gate for this phase.
- Cover portrait and landscape, compact Android viewports, safe-area insets, browser chrome/visual viewport changes and touch target sizes. VisualViewport resize and safe-area metadata are now covered by merged-main browser acceptance; physical notch testing remains open.
- Verify independent simultaneous pointers for steering, throttle, brake and nitro, including pointer cancel, lost capture, tab switch, pause, retry and orientation changes.
- Verify gyro permission, neutral calibration, sensitivity, direction and graceful fallback when sensors are unavailable.
- Set explicit performance budgets for frame time, long tasks, memory growth, asset decode and WebGL upload; test software WebGL and context restoration.
- Capture mobile screenshots and console/page errors as CI artifacts. Never label physical-device acceptance as complete based only on Playwright simulation.

### P1 — Stabilize the racing game

- Reconcile any newly opened racing PR against main before feature work. The remaining open PR is #92 (stale draft billboard branch, diverged/non-mergeable). PR #179 was merged as a documentation snapshot; this roadmap refresh supersedes its stale baseline. City budget/tax controls, accessible budget dialog and VisualViewport/safe-area behavior are merged in PRs #182, #185 and #186.
- Confirm the tenfold track-length and steering correction in PR #132 against current main behavior and automated evidence.
- Keep vehicle physics, input sampling, rendering and progression as separate testable domains.
- Verify a complete real race: countdown, driving, collisions, pickups, laps, finish, reward and persisted progress. Do not weaken finish/reward assertions to make smoke tests pass.
- Keep all runtime assets local or provide deterministic, non-blocking fallbacks; validate service-worker cache version and offline boot.

### P1 — Turn the city slice into a coherent simulation

- Treat the city as a separate product domain with its own state model, simulation clock, renderer, input and persistence adapter.
- Build in vertical slices: roads/connectivity → zoning → buildings and growth → population/jobs → utilities/services → traffic → budget/economy → save/load.
- Each system must have deterministic unit tests, integration tests and mobile browser acceptance for placement, simulation progression and persistence. Budget/tax controls and their accessible mobile dialog are accepted in PRs #182 and #185; versioned save migration/recovery is accepted in PR #188; workforce matching is accepted in PR #190; finite service capacity is accepted in PR #192; resident wellbeing integration is accepted in PR #193. Workforce-aware zoning growth is under validation in PR #195.
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
- Keep Pages deployment separate from validation; never deploy from an unverified feature branch.
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

## Current execution queue

| Priority | Work item | Status | Exit condition |
|---|---|---|---|
| P0 | Refresh evidence and reconcile PR inventory | 🟢 verified on main bb2eea0 | Current commit, all required CI runs, Pages deployment and open-PR inventory recorded |
| P0 | Mobile race + city acceptance matrix | 🟢 CI acceptance; 🟡 physical-device gate | Main run 41614496592 passes city immersive entry, city viewport resizing, mobile touch/gyro/orientation checks, full rewarded three-lap race and offline PWA. Physical Android safe-area and performance checks remain external |
| P1 | Racing stability and real-finish regression | 🟢 browser acceptance verified | Full three-lap mobile race, five-car standings, rewards, achievement persistence and offline launch pass; continue real-device physics/performance tuning |
| P1 | City simulation vertical slices | 🟡 in progress | Roads/connectivity, zoning, building growth, bounded pedestrian agents, traffic and budget/tax simulation have browser acceptance; next complete job matching/demand, service effects, save migration/recovery and device performance |
| P2 | Enforce dependency boundaries | 🟢 implemented and CI-verified | Continue monitoring domain imports, unresolved paths, cycles and module size |
| P2 | Reproducible CI and release gates | 🟡 in progress | Keep lockfile-backed install, least privilege, exact-head checks and successful main Pages deployment |
| P3 | Cocos Editor import and Web build | 🔴 not yet verified | Editor-generated Web build runs on Android; requires Cocos Creator 3.8.6 environment |
## Non-goals for this phase

- No broad rewrite or destructive file moves.
- No forced merge of all open PRs.
- No desktop-browser gate that blocks mobile-first delivery.
- No claim of physical Android or Cocos Editor acceptance without actual device/Editor evidence.
- No production Worker deployment or paid infrastructure dependency without a product requirement.
