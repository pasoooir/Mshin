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
