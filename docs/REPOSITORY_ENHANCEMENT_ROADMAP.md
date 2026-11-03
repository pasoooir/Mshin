# Mshin Repository Enhancement Roadmap

**Reviewed:** 2026-11-03  
**Baseline:** `main` at `bc329187b39e1e2d0bb84b57e53b2e24ca436bde`  
**Primary users:** mobile browsers (Android-first)  
**Delivery:** GitHub Pages; optional Cloudflare Worker remains separate from the playable client.

## Mission

Improve the repository as a maintainable two-game product (racing + city simulation), not as a collection of disconnected PRs. Preserve working gameplay, avoid broad rewrites, and make every enhancement traceable to code, tests and acceptance evidence.

## Verified baseline

- Main contains separate browser racing and city entry points, portable TypeScript/Cocos source, a service worker, local assets, data validation, unit tests and GitHub Actions.
- Latest merged-main mobile browser evidence: [run 41604548181](https://github.com/pasoooir/Mshin/actions/runs/41604548181) — success; includes city smoke, mobile touch/rendering smoke, full three-lap rewarded race in portrait-phone viewport, finish-panel bounds, saved rewards/achievements and offline PWA launch.
- Latest merged-main portable validation evidence: [run 41604547975](https://github.com/pasoooir/Mshin/actions/runs/41604547975) — success.
- Latest merged-main GitHub Pages deployment: [run 41604546842](https://github.com/pasoooir/Mshin/actions/runs/41604546842) — success.
- PR #176 is merged as `616be0381f3eeda0c8923b288e33467361493a5d`; it adds portrait-mobile full-race acceptance, compact finish-screen layout, screenshot evidence and offline acceptance. PR #175 was closed as a superseded duplicate. PRs #161–#174 and #176 are merged.
- Mobile gameplay preview artifact: [mshin-mobile-gameplay-previews](https://github.com/pasoooir/Mshin/actions/runs/41604548181/artifacts/13216086671).
- PR #178 merged as `c19e7273f4ec5bb9bb583cda58038a749872734f`; city entry requests fullscreen before landscape lock, retries on the first trusted touch/click, and retains a portrait fallback. Mobile city smoke and portable validation passed (runs 41606148309 and 41606148420).
- PR #177 merged as `b55ba56bed2c2ebdb08ba0707df9a786a5fa0a72`; deterministic bounded pedestrians follow road tiles, synchronize to residential occupancy, migrate old saves and render through instanced 3D meshes. Exact-head validation and mobile smoke passed (runs 41606720934 and 41606720997).
- PR #180 merged as `f3e26f981c09ea57afb5395423d53a55471115a3`; adds home-demolition pedestrian reassignment regression coverage. All 41 Node tests and portable checks passed on exact head (run 41607752900).
- Latest main portable validation and GitHub Pages deployment for `bc329187b39e1e2d0bb84b57e53b2e24ca436bde` passed (runs 41608035350 and 41608035227). The main mobile smoke is still running (run 41608035368); do not claim that run as passed until it completes.
- CI success is not equivalent to physical Android-device certification or Cocos Creator Editor/Web build acceptance.

## Product priorities

### P0 — Protect mobile playability

- Keep mobile-only browser smoke as the required interactive browser gate for this phase.
- Cover portrait and landscape, compact Android viewports, safe-area insets, browser chrome/visual viewport changes and touch target sizes.
- Verify independent simultaneous pointers for steering, throttle, brake and nitro, including pointer cancel, lost capture, tab switch, pause, retry and orientation changes.
- Verify gyro permission, neutral calibration, sensitivity, direction and graceful fallback when sensors are unavailable.
- Set explicit performance budgets for frame time, long tasks, memory growth, asset decode and WebGL upload; test software WebGL and context restoration.
- Capture mobile screenshots and console/page errors as CI artifacts. Never label physical-device acceptance as complete based only on Playwright simulation.

### P1 — Stabilize the racing game

- Reconcile any newly opened racing PR against main before feature work. The remaining open PR is #92 (stale draft billboard branch, diverged/non-mergeable). PR #179 was merged as a documentation snapshot; this roadmap refresh supersedes its stale baseline. City budget/tax controls are under mobile acceptance in PR #181.
- Confirm the tenfold track-length and steering correction in PR #132 against current main behavior and automated evidence.
- Keep vehicle physics, input sampling, rendering and progression as separate testable domains.
- Verify a complete real race: countdown, driving, collisions, pickups, laps, finish, reward and persisted progress. Do not weaken finish/reward assertions to make smoke tests pass.
- Keep all runtime assets local or provide deterministic, non-blocking fallbacks; validate service-worker cache version and offline boot.

### P1 — Turn the city slice into a coherent simulation

- Treat the city as a separate product domain with its own state model, simulation clock, renderer, input and persistence adapter.
- Build in vertical slices: roads/connectivity → zoning → buildings and growth → population/jobs → utilities/services → traffic → budget/economy → save/load.
- Each system must have deterministic unit tests, integration tests and mobile browser acceptance for placement, simulation progression and persistence.
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
| P0 | Refresh stale tracker and define repository-wide acceptance policy | 🟢 completed in this documentation change | Current baseline and evidence links recorded |
| P0 | Reconcile open PR inventory and stacked dependencies | 🟢 inventory reconciled | PRs #161–#180 are merged (PR #179 is documentation-only); #175 was closed as superseded. PR #92 remains stale/blocked pending rebase and mobile billboard acceptance. Recheck after any new PR activity. |
| P0 | Mobile race + city acceptance matrix | 🟡 in progress | Main run 41604548181 passes portrait 390×844 software-landscape touch race; PR #178 run 41606148309 additionally verifies city fullscreen-before-landscape sequencing and mobile city interactions. Broaden to safe-area/visual-viewport changes, pointer cancellation, gyro and representative physical Android devices. |
| P1 | Racing stability and real-finish regression | 🟢 browser acceptance verified | Main run 41604548181 passes the full three-lap mobile race, five-car standings, rewards, first-finish achievement and persisted progress. Physical Android performance/balance remains a separate gate. |
| P1 | City simulation vertical slices | 🟡 in progress | Each system passes deterministic, integration and mobile acceptance |
| P2 | Enforce dependency boundaries | 🟢 implemented and CI-verified | PR #174 merged; latest accepted main validation before current queued run is 41607496456, and exact-head validation for pedestrian regression is 41607752900. Continue monitoring as modules evolve. |
| P2 | Reproducible CI and release gates | 🟡 in progress | Lockfile-backed install, least privilege, isolated Pages deployment |
| P3 | Cocos Editor import and Web build | 🔴 not yet verified | Editor-generated Web build runs on Android |

## Non-goals for this phase

- No broad rewrite or destructive file moves.
- No forced merge of all open PRs.
- No desktop-browser gate that blocks mobile-first delivery.
- No claim of physical Android or Cocos Editor acceptance without actual device/Editor evidence.
- No production Worker deployment or paid infrastructure dependency without a product requirement.
