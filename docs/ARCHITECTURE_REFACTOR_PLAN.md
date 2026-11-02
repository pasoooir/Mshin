# Mshin Modular Game Architecture & Refactoring Plan

**Status:** repository audit and staged refactoring proposal  
**Baseline:** `main` at `ad2b32bd40cd2940ad9c866459798a2ebdf06b86` (2026-11-02)  
**Scope:** Racing game, Sims City, shared runtime, assets, tests and CI.

## 1. Executive decision

Adopt the proposed responsibility-based separation, with one important refinement: **do not merge unrelated modules into giant files**. The goal is to reduce the number of files touched by each contributor and establish stable ownership boundaries. Keep modules independently testable and expose narrow interfaces between them.

The repository already contains partial separation, but it is not yet a clean two-game architecture. It currently mixes:
- a browser racing implementation under `src/`;
- a Cocos Creator + TypeScript implementation under `assets/scripts/`;
- a city browser implementation under `src/city/` and `city.html`;
- shared asset, audio, boot, data and worker infrastructure.

Do not move or rename all existing files in one PR. First establish dependency boundaries and tests, then migrate one vertical slice at a time.

## 2. Observed repository structure

The following paths were verified from the `main` tree:

### Racing/browser runtime
- `src/web-game.js` — approximately 79.7 KB; browser game orchestration, UI and race loop.
- `src/race-renderer-3d.js` — approximately 37.2 KB; 3D race rendering.
- `src/aerial-environment.js`, `src/showroom-3d.js`, `src/vehicle-showroom-3d.js`
- `src/vehicle-dynamics.js`, `src/traffic-ai.js`, `src/vehicle-controls.js`
- `src/collision-physics.js`, `src/rigid-body-physics.js`, `src/tire-physics.js`, `src/vehicle-destruction.js`, `src/vehicle-damage-visuals.js`
- `src/audio.js`, `src/multitouch-input.js`, `src/physics.js`, `src/pickup-collection.js`
- `src/game.js`, `src/boot.js`, `src/progress.ts`, `src/stage-catalog.ts`

### Cocos Creator / TypeScript runtime
- `assets/scripts/MshinGame.ts`
- `assets/scripts/VehicleController.ts`
- `assets/scripts/VehicleDamageRenderer.ts`
- `assets/scripts/WorldRenderer.ts`
- `assets/scripts/ProgressStore.ts`
- `assets/scenes/` and `assets/resources/` are separate asset locations and must be audited before migration.

### Sims City
- `city.html`
- `src/city/city-view.js`
- `src/city/city-view.css`

### Shared and project infrastructure
- `src/asset-loader.js`, `src/asset-manifest.json`
- `assets/vector/` contains car and world SVG assets.
- `data/stages.json`, `data/worlds.json`
- `workers.js`, `wrangler.toml`, `service-worker.js`
- `scripts/`, `tests/`, `docs/`, `.github/`

**Important:** the racing game currently has both browser-JavaScript and Cocos TypeScript code. These are not automatically interchangeable implementations. Before consolidation, determine which runtime is authoritative for the published game and whether the Cocos project is a parallel port, an experiment, or a future target. Do not silently delete either implementation.

## 3. Target architecture

Use domain folders and small modules. The names below describe responsibility boundaries; they are not a demand to create empty placeholder files.

```text
games/
  racing/
    app/          # entry point, race lifecycle, orchestration
    graphics/     # track renderer, lighting, shadows, environment
    vehicles/     # vehicle model, dynamics, damage, traffic AI
    tracks/       # track geometry, stages, hazards, pickups
    controls/     # touch, joystick, gyro, keyboard, input state
    audio/        # racing audio and music
    economy/      # currency, garage, upgrades, rewards
    progression/  # stages, unlocks, records
  city/
    app/          # city entry point and lifecycle
    graphics/     # renderer, camera, lighting, shadows
    buildings/    # building definitions and placement
    roads/        # road graph and transport network
    citizens/     # agents, needs and behavior
    vehicles/     # city traffic and vehicle agents
    nature/       # trees, animals, vegetation
    economy/      # budget, taxes, services
    simulation/   # deterministic simulation clock and systems
shared/
  assets/         # manifest, loading, cache and fallback policy
  audio/          # shared audio primitives only
  platform/       # viewport, input primitives, persistence adapters
  utilities/      # pure helpers and common types
tests/
  racing/
  city/
  shared/
scripts/
docs/
```

The existing root `src/` and `assets/scripts/` should be migrated gradually into this layout only after import/dependency maps and runtime entry points are documented.

## 4. Module ownership and change rules

| Area | Primary ownership | Allowed dependencies |
|---|---|---|
| `games/racing/**` | Racing contributors | `shared/**` public interfaces |
| `games/city/**` | City contributors | `shared/**` public interfaces |
| `shared/**` | Designated platform/architecture owner | No imports from either game |
| `tests/racing/**` | Racing contributors | Racing public API |
| `tests/city/**` | City contributors | City public API |
| `tests/shared/**` | Shared owner | Shared public API |

Rules:
1. Racing PRs must not edit City modules; City PRs must not edit Racing modules.
2. Neither game may import another game's private modules.
3. Shared modules must not import from `games/racing` or `games/city`.
4. Shared API changes require a dedicated PR and compatibility tests.
5. Each feature PR should normally change one domain module plus its focused tests and, if necessary, its documentation.
6. Do not split a coherent change into many PRs that all modify the same entry point.
7. Avoid giant barrel files and giant "all-in-one" source files. Use explicit public entry points per domain.
8. File moves must preserve behavior and be separated from feature changes where practical.

## 5. File consolidation: what is safe

Consolidation should be based on cohesion and dependency direction, not file count alone.

Potential candidates after dependency review:
- small, tightly coupled vehicle damage helpers can be grouped behind a vehicle-damage module;
- small input primitives can be grouped behind a racing-controls facade;
- city view and its CSS remain together as one city presentation module, but simulation logic must not be folded into the view;
- stage catalog and stage validation may share a progression/data boundary, but JSON data should remain data files;
- audio implementation and audio configuration may share a module boundary, while audio assets remain separate.

Do **not** combine:
- all racing systems into one `RacingEngine.ts`;
- all city systems into one `CityEngine.ts`;
- renderer, physics, input and economy into a single source file;
- tests, assets, data and executable code;
- browser runtime and Cocos runtime before choosing the authoritative runtime.

## 6. Refactoring sequence and acceptance gates

### Phase 0 — Baseline and ownership (this document)
- Record the actual source tree and runtime entry points.
- Identify duplicate/parallel implementations.
- Define module ownership and import rules.
- No runtime code moves in this phase.

### Phase 1 — Dependency and runtime map
- Trace imports and script tags from `index.html`, `city.html`, Cocos scenes and project settings.
- Identify dynamic imports, global state, window globals, service-worker caching and asset-manifest consumers.
- Produce a machine-readable dependency report.
- Identify the authoritative racing runtime and the city runtime.
- Acceptance: all production entry points and their transitive local dependencies are accounted for.

### Phase 2 — Boundary enforcement
- Add import-boundary checks for Racing, City and Shared.
- Add path-specific CI so a Racing-only PR does not run unrelated City browser tests unless shared code changed, and vice versa.
- Keep a full integration workflow for release/merge gates.
- Acceptance: a deliberate cross-domain import fails CI; valid independent modules pass.

### Phase 3 — Incremental module extraction
- Extract one domain at a time behind stable APIs.
- Start with low-coupling shared utilities/assets, then racing controls/vehicles, then city simulation/presentation.
- Move tests with modules and preserve public entry points.
- Acceptance: unit tests and focused browser smoke pass after every extraction; no unverified mass rename.

### Phase 4 — Runtime and asset quality
- Keep CDN assets pinned to versioned URLs or vendored locally where licensing permits.
- Store attribution/license/source metadata.
- Preload critical assets; use local fallback assets for offline and CDN failures.
- Avoid relying on mutable `latest` URLs in production.
- Acceptance: no broken asset requests in browser smoke, and core gameplay remains functional offline.

### Phase 5 — Merge and deployment discipline
- One PR per bounded architectural slice.
- Rebase/update branch only when needed; resolve conflicts in the owning module.
- Run focused checks on every PR and full integration/browser smoke before merge.
- Verify deployed GitHub Pages after merge.
- Acceptance: no merge is considered complete until CI and live smoke evidence are available.

## 7. CI strategy

Recommended workflow split:
- `racing-unit.yml`: racing physics, vehicles, tracks, controls, renderer and audio unit tests.
- `racing-browser.yml`: racing browser smoke and mobile controls.
- `city-unit.yml`: city simulation and city view tests.
- `city-browser.yml`: desktop/mobile city browser smoke.
- `shared-contracts.yml`: asset loader, shared utilities and boundary checks.
- `integration.yml`: complete suite on main, release candidates and changes to shared infrastructure.

Use path filters to avoid unrelated work, but always retain a full integration run before release. Do not create multiple workflows that repeat the same test suite for the same event.

## 8. Immediate risks and blockers discovered

1. `src/web-game.js` and `src/race-renderer-3d.js` are large orchestration/rendering files and likely high-contention merge hotspots.
2. City currently has a small two-file browser implementation, while the Racing browser runtime is much more decomposed. City simulation foundations and feature work must not be mixed into Racing PRs.
3. The Cocos TypeScript implementation sits under `assets/scripts/`, outside the browser runtime's `src/` layout. Its production status and scene references must be resolved before any large move.
4. Root-level asset loading, service-worker caching and global state may couple otherwise separate game modules.
5. The repository currently has many open PRs across racing, city, renderer, input, physics and documentation. Large-scale file moves while those branches are active would create avoidable conflicts. First inventory and sequence existing PRs; do not run a mass refactor in parallel with active changes to the same files.

## 9. Immediate next engineering tasks

1. Complete Phase 1 dependency/runtime map from the default branch and open PRs.
2. Audit open PR overlap by changed path and group conflicting PRs.
3. Add architecture boundary tests without moving runtime files.
4. Create a single, staged migration PR for the first low-risk module boundary.
5. Keep gameplay bug fixes (vehicle movement, race state, wrong character/portrait asset) separate from structural moves so regressions can be attributed and tested.

## 10. Definition of done

This architecture is considered adopted only when:
- Racing and City have separate entry points and dependency graphs.
- Shared code is genuinely game-agnostic.
- Boundary checks prevent cross-game imports.
- Contributors can work in separate folders without editing the same files.
- Focused and full browser tests pass.
- Existing features and save/progression data remain compatible.
- GitHub Pages deployment is verified after merge.

A lower file count by itself is not a success metric. The success metrics are fewer overlapping PR paths, fewer merge conflicts, shorter focused CI runs, and preserved gameplay behavior.

## 11. Phase 1 — verified runtime and dependency map (2026-11-02)

This section records the executable entry points and import edges verified against `main` at the audit time. It deliberately distinguishes what is proven by source references from what still requires a scene/build audit.

### 11.1 Published browser entry points

| Surface | HTML entry | Runtime entry | Verified behavior |
|---|---|---|---|
| Racing | `index.html` | `src/boot.js` | The page loads accessibility and boot modules. Boot preloads the manifest, then dynamically imports `src/web-game.js`. |
| City | `city.html` | `src/city/city-view.js` | The page directly loads the city view as an ES module. |
| Offline shell | Both pages | `service-worker.js` | Both pages register the same root service worker on secure origins. |

The racing page also contains inline orientation/viewport and service-worker registration logic. The browser runtime is therefore the currently published, directly reachable implementation; the Cocos TypeScript source is a parallel project implementation, not the entry point referenced by either published HTML page.

### 11.2 Racing browser dependency graph

```text
index.html
  ├─ inline orientation/viewport helpers (window.MshinOrientation)
  ├─ src/menu-accessibility.js
  └─ src/boot.js
       ├─ src/asset-loader.js
       │    └─ src/asset-manifest.json
       │         ├─ assets/vector/car-*.svg
       │         ├─ assets/vector/world-*.svg
       │         ├─ cdn/assets/scenes/scene-*.jpg
       │         ├─ cdn/assets/icons/*
       │         └─ cdn/assets/audio/*
       └─ dynamic import: src/web-game.js
            ├─ vehicle-controls.js
            ├─ multitouch-input.js
            ├─ audio.js
            ├─ race-renderer-3d.js
            │    ├─ vehicle-showroom-3d.js
            │    │    └─ vehicle-pbr.js
            │    ├─ vehicle-pbr.js
            │    └─ vehicle-controls.js
            ├─ vehicle-showroom-3d.js
            ├─ aerial-environment.js
            ├─ collision-physics.js
            ├─ rigid-body-physics.js
            ├─ vehicle-dynamics.js
            │    └─ tire-physics.js
            ├─ pickup-collection.js
            ├─ vehicle-damage-visuals.js
            ├─ traffic-ai.js
            └─ vehicle-destruction.js
```

Additional observations:
- `src/game.js` imports `src/physics.js`, but neither `index.html` nor `src/boot.js` references `src/game.js`. Treat it as an apparently legacy/unwired module until repository-wide references confirm otherwise.
- `src/web-game.js` publishes diagnostic/runtime objects on `window`, including `Mshin3DRenderer`, `MshinVehicleShowroom`, `MshinPerformance`, `MshinTrafficRoster`, `MshinViewport`, `MshinShowroom` and gyro/boot diagnostics. These globals are implicit integration contracts used by tests and browser diagnostics; do not move or rename them without a compatibility layer.
- The main racing runtime has a large orchestration surface. Extract behavior behind focused interfaces before moving files; avoid changing its entry import in the same PR as unrelated gameplay changes.

### 11.3 City browser dependency graph

```text
city.html
  └─ src/city/city-view.js
       ├─ DOM/canvas presentation and input handling
       ├─ city state/simulation helpers (currently in the same module)
       └─ window.MshinCityDebug (browser test/debug contract)
```

The city page has no observed ES-module imports in its current view entry. The simulation/view separation is therefore an internal extraction opportunity, but should be introduced with focused city tests and a stable city-view API.

### 11.4 Cocos TypeScript dependency graph

The Cocos scripts are not referenced by the published browser HTML entry points. Their observed source-level graph is:

```text
assets/scripts/MshinGame.ts
  ├─ cc (Cocos Creator engine)
  ├─ src/stage-catalog.ts
  ├─ src/cocos-core.ts
  ├─ assets/scripts/VehicleController.ts
  │    ├─ cc
  │    ├─ src/cocos-core.ts
  │    └─ src/stage-catalog.ts
  ├─ assets/scripts/VehicleDamageRenderer.ts
  │    ├─ cc
  │    └─ assets/scripts/VehicleController.ts
  ├─ assets/scripts/WorldRenderer.ts
  │    ├─ cc
  │    └─ src/stage-catalog.ts
  └─ assets/scripts/ProgressStore.ts
       ├─ cc
       ├─ src/stage-catalog.ts
       └─ src/progress.ts
```

This confirms code-level dependencies but does not prove which Cocos scene is configured as the launch scene. Before any Cocos file migration, inspect `project.json`, `settings/v2/packages` (if present), scene assets, UUID/meta references and Creator build settings.

### 11.5 Shared offline/cache boundary

- Both browser pages register the root `service-worker.js`.
- The worker's precache list explicitly includes the racing browser runtime, its physics/control/render modules, `src/asset-loader.js` and `src/asset-manifest.json`.
- The asset manifest is the source of truth for car/world SVGs, scene images, control icons and audio files.
- Any future module extraction must update the service-worker precache strategy and offline tests in the same bounded change. A module that works online but is absent from the offline cache is not considered integrated.

### 11.6 Ownership and safe first extraction

| Existing area | Target ownership | Initial action |
|---|---|---|
| `src/vehicle-controls.js`, `src/multitouch-input.js` | Racing / Controls | Add contract tests and isolate the public input API; keep legacy imports stable. |
| `src/vehicle-dynamics.js`, `src/tire-physics.js`, `src/collision-physics.js`, `src/rigid-body-physics.js` | Racing / Vehicles + Physics | Keep physics pure and renderer-independent; map consumers before extraction. |
| `src/traffic-ai.js`, `src/vehicle-destruction.js`, `src/vehicle-damage-visuals.js` | Racing / Vehicles | Separate simulation state from visual effects. |
| `src/asset-loader.js`, `src/asset-manifest.json` | Shared / Assets | Treat manifest keys and fallback behavior as a public contract. |
| `src/city/city-view.js` | City / App + Graphics + Simulation | Extract pure simulation helpers first; keep DOM/canvas ownership in the view. |
| `assets/scripts/**`, `src/cocos-core.ts` | Cocos Racing runtime | Keep separate until scene/build authority and import mapping are verified. |

### 11.7 Phase 1 completion limits

Verified: the published browser entry points, the racing boot/preload chain, the static ES-module imports listed above, key global debug contracts, the asset-manifest dependency, service-worker registration, and the Cocos source import graph.

Not yet verified: every Cocos scene UUID/reference, all dynamically constructed asset paths, the complete test-to-runtime dependency graph, all workflow path filters, and whether every file in `src/` has an active production consumer. Those are explicit follow-up checks, not assumed facts.

**Phase 1 status: partially complete.** Do not start mass file moves yet. Next, audit PR changed-path overlap and complete Cocos scene/asset UUID tracing; then add boundary checks in a separate, testable change.

## 12. Open-PR overlap audit (2026-11-02)

Changed-file lists were retrieved from GitHub for the open PR inventory. This is a path-overlap audit, not a claim that the PRs are semantically compatible or that their checks pass.

### 12.1 High-contention files

| Hotspot | PRs touching the path | Consequence |
|---|---|---|
| `src/web-game.js` | #132, #136, #141, #99, #114, #65, #74, #113, #112, #111, #110, #115, #107, #117, #116, #108, #62 | Critical serialization point. Do not merge these branches in parallel or assume one branch includes another. |
| `tests/browser-smoke.mjs` | #132, #136, #141, #142, #99, #114, #65, #74, #102, #113, #112, #111, #110, #115, #107, #117, #116, #108, #62 | Same test file is a shared integration contract; changes need ordered rebasing and one final full browser run. |
| `src/race-renderer-3d.js` | #132, #136, #141, #142, #140, #146, #94, #92, #89 | Renderer work is heavily stacked/overlapping; merge order must be dependency-driven. |
| `index.html` | #132, #140, #114, #65, #113, #112, #111, #117, #116, #108, #62, #93 | UI, input, viewport and asset changes collide in the main page. |
| `service-worker.js` | #99, #114, #65, #74, #108, #62 | Offline cache updates must be coordinated with runtime and asset-manifest changes. |
| City view | #144 and #145 both change `src/city/city-view.js`; #143/#144 both change `city.html`; #143/#144/#145 all change `tests/city-browser-smoke.mjs` | City PRs are not independent despite their descriptions. They need a single integration sequence. |

### 12.2 Recommended integration lanes

1. **City lane:** #145 (view/performance) and #144 (map/navigation) share `city-view.js`; #143 shares the city browser test and overlaps #144 on `city.html`. Integrate only after reviewing combined diffs and running the complete city browser smoke on the combined candidate. Do not merge them as independent PRs based only on their titles.
2. **Renderer lane:** #136/#141/#142/#140/#146/#132 all touch the renderer directly or its smoke acceptance. Resolve the underlying renderer-budget and mobile-canvas behavior first; then layer visual materials (#146) after renderer behavior is stable. #142 is explicitly diagnostic and should not be treated as a fix by itself.
3. **Controls/physics lane:** #132, #99 and #117 overlap control/dynamics and the browser smoke. Select the intended latest implementation by comparing base/head ancestry and patches, not by PR number alone.
4. **Legacy runtime lane:** #65/#62/#74 and the later menu/input/asset PRs overlap entry HTML, asset manifest, service worker and web-game. Verify whether these branches are superseded by main before attempting integration.
5. **Shared smoke-test lane:** any PR changing `tests/browser-smoke.mjs` must be rebased against the current integrated candidate and run after all runtime changes it validates.

### 12.3 Operational policy from this audit

- Do not start more feature PRs against the high-contention files while an integration candidate is being assembled.
- Do not merge a PR solely because its own branch CI is green: branch checks can be stale and can omit later changes from another PR.
- Before merging a cluster, build one candidate branch from current `main`, apply the selected changes in dependency order, resolve conflicts once, then run unit checks and the full desktop/mobile browser smoke against that exact candidate.
- Keep PRs that are superseded or no longer relevant open until their patches have been compared; close only after confirming their changes are included or intentionally abandoned.
- Prefer future module work to use domain-owned files and tests, with compatibility adapters at the current entry points. This is the concrete way to reduce merge conflicts; simply combining files would make the hotspots worse.

**Phase 1 status: dependency map recorded; overlap audit recorded.** Full Cocos scene/UUID tracing and exact branch ancestry/supersession analysis remain open. No runtime code has been moved.

