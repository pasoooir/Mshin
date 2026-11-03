# Mshin Repository Enhancement Roadmap

**Reviewed:** 2026-11-03 after PR #197  
**Baseline:** `main` at `7bdf75b2ad98d9f54d553cd47f95913e671bf816`  
**Primary users:** mobile browsers (Android-first)  
**Delivery:** GitHub Pages; optional Cloudflare Worker remains separate from the playable client.

## Mission

Improve the repository as a maintainable two-game product (racing + city simulation), not as a collection of disconnected PRs. Preserve working gameplay, avoid broad rewrites, and make every enhancement traceable to code, tests and acceptance evidence.

## Verified baseline

- **Current main:** `7bdf75b2ad98d9f54d553cd47f95913e671bf816`, after PR #197.
- **Merged city milestones:** PR #188 versioned save migration/backup recovery; PR #190 workforce matching and employment demand; PR #192 finite utility and civic-service capacity; PR #193 resident wellbeing integration; PR #195 workforce-aware zoning growth.
- **Main release evidence:** after PR #195, run `41625952666` — build, validation and GitHub Pages deployment succeeded. Main mobile browser smoke run `41625957359` remained in progress.
- **Main after PR #197:** commit `7bdf75b2ad98d9f54d553cd47f95913e671bf816`; `build` and `validate` succeeded, `deploy` is in progress, and main `browser-smoke` is still in progress.
- **PR #197:** merged as `7bdf75b2ad98d9f54d553cd47f95913e671bf816`; occupied-home service satisfaction is weighted by resident count and now affects city happiness. Exact-head portable validation, city services/economy, road/zoning/traffic, population/employment, save-recovery, Android-sized viewport and PR browser-smoke checks passed.
- **PR #198:** workflow concurrency correction is open; portable validation passes and browser smoke is running.
- **PR #196:** this evidence refresh is open; portable validation passes; mobile browser smoke is running.
- **Primary users:** mobile browsers (Android-first). **Delivery:** GitHub Pages; optional Cloudflare Worker remains separate from the playable client.
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

- Reconcile any newly opened racing PR against main before feature work. PR #92 remains a stale draft billboard branch (diverged/non-mergeable), not an active racing delivery. Current open PR inventory: #196 (execution documentation), #198 (workflow concurrency), and stale draft #92. PR #179 was merged as a documentation snapshot; this roadmap refresh supersedes its stale baseline. City budget/tax controls, accessible budget dialog and VisualViewport/safe-area behavior are merged in PRs #182, #185 and #186.
- Confirm the tenfold track-length and steering correction in PR #132 against current main behavior and automated evidence.
- Keep vehicle physics, input sampling, rendering and progression as separate testable domains.
- Verify a complete real race: countdown, driving, collisions, pickups, laps, finish, reward and persisted progress. Do not weaken finish/reward assertions to make smoke tests pass.
- Keep all runtime assets local or provide deterministic, non-blocking fallbacks; validate service-worker cache version and offline boot.

### P1 — Turn the city slice into a coherent simulation

- Treat the city as a separate product domain with its own state model, simulation clock, renderer, input and persistence adapter.
- Build in vertical slices: roads/connectivity → zoning → buildings and growth → population/jobs → utilities/services → traffic → budget/economy → save/load.
- Each system must have deterministic unit tests, integration tests and mobile browser acceptance for placement, simulation progression and persistence. Budget/tax controls and their accessible mobile dialog are accepted in PRs #182 and #185; versioned save migration/recovery is accepted in PR #188; workforce matching is accepted in PR #190; finite service capacity is accepted in PR #192; resident wellbeing integration is accepted in PR #193. Workforce-aware zoning growth is accepted in PR #195. Resident-weighted service satisfaction is under validation in PR #197.
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
| P0 | Refresh evidence and reconcile PR inventory | 🟡 current main 7bdf75b; build/validate pass, deploy and main browser smoke running | Record final browser-smoke result and refresh the exact open-PR inventory after PR #196/#198 resolve |
| P0 | Mobile race + city acceptance matrix | 🟢 CI acceptance; 🟡 physical-device gate | PR #195 exact-head mobile viewport and full rewarded-race/offline browser acceptance pass; main-after-merge browser smoke is running. Physical Android safe-area and performance checks remain external |
| P1 | Racing stability and real-finish regression | 🟢 PR #195 exact-head browser acceptance verified | Full three-lap mobile race, five-car standings, rewards, achievement persistence and offline launch pass; continue real-device physics/performance tuning |
| P1 | City simulation vertical slices | 🟡 in progress | Roads, zoning, growth, pedestrians, traffic, budget/tax, workforce matching, finite services, save migration and wellbeing are implemented; PR #197 implements per-building resident-weighted service satisfaction. Next: job assignment/commuting and deeper economic feedback |
| P2 | Enforce dependency boundaries | 🟢 implemented and CI-verified | Continue monitoring domain imports, unresolved paths, cycles and module size |
| P2 | Reproducible CI and release gates | 🟡 in progress | Keep lockfile-backed install, least privilege, exact-head checks, PR #198 is testing a shared push/PR concurrency key and successful main Pages deployment |
| P3 | Cocos Editor import and Web build | 🔴 not yet verified | Editor-generated Web build runs on Android; requires Cocos Creator 3.8.6 environment |
## Non-goals for this phase

- No broad rewrite or destructive file moves.
- No forced merge of all open PRs.
- No desktop-browser gate that blocks mobile-first delivery.
- No claim of physical Android or Cocos Editor acceptance without actual device/Editor evidence.
- No production Worker deployment or paid infrastructure dependency without a product requirement.
