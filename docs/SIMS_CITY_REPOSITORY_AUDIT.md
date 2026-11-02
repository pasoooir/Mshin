# Sims City — Repository Audit (Phase 0)

**Repository:** `pasoooir/Mshin`  
**Audited ref:** `main` (2026-11-02)  
**Purpose:** establish a fact-based baseline before introducing city simulation. This is an audit, not a claim that the Sims City feature set already exists.

## 1. Executive finding

The repository is a working-in-progress browser racing game with a parallel Cocos Creator 3.8.6 source integration. It is **not yet a complete, editor-verified Cocos Creator game project** and it does not yet contain a city-building simulation.

The safest strategy is an incremental expansion of the existing game, not a rewrite:
- Preserve the current browser racing runtime, race progression, vehicle physics, controls, rendering and assets.
- Build the city simulation as independent TypeScript domain modules with deterministic tests.
- Introduce a shared world/road coordinate model so the existing driving mode can later operate on city roads.
- Keep the browser runtime playable throughout development.
- Treat the Cocos runtime as a separate adapter until a serialized scene and engine-native build are verified in Cocos Creator 3.8.6.

## 2. Repository and build baseline

| Item | Observed state |
|---|---|
| Repository | Public GitHub repository `pasoooir/Mshin` |
| Default branch | `main` |
| GitHub Pages | Enabled; deployment workflow currently reports success |
| Package | `mshin-3d-racing`, version `0.15.2` |
| Cocos Creator version declared | `3.8.6` in root `package.json` |
| TypeScript | `^5.8.3` |
| Node requirement | `>=20`; latest observed Actions runner used Node `22.23.4` |
| Main scripts | `npm run check`, `npm test`, `npm run build:core` |
| Browser runtime | `src/web-game.js`, Canvas 2D HUD/world fallback plus a separate WebGL 3D race renderer |
| Cocos source | `assets/scripts/*.ts`, `src/cocos-core.ts` |
| Test suite | Node built-in test runner; browser acceptance uses Playwright |
| Repository tree | 206 entries in recursive tree response at audit time |

### Build/test commands declared by the repository
- `npm run validate:data`
- `npm run build:core`
- `npm run check:js-syntax`
- `npm run check:cocos-syntax`
- `npm run check:worker`
- `npm test`
- `npm run check` (combined validation)

The project requires Node.js 20 or newer. The CI run inspected used Node.js 22.23.4.

## 3. Existing implementation inventory

### 3.1 Browser game and driving

The current browser game is a racing product, not a city simulation. Existing implementation files include:
- `src/web-game.js`, `src/game.js`, `src/boot.js`
- `src/vehicle-dynamics.js`, `src/physics.js`, `src/rigid-body-physics.js`
- `src/tire-physics.js`, `src/collision-physics.js`, `src/vehicle-destruction.js`
- `src/vehicle-controls.js`, `src/multitouch-input.js`
- `src/traffic-ai.js`, `src/pickup-collection.js`
- `src/race-renderer-3d.js`, `src/aerial-environment.js`
- `src/vehicle-showroom-3d.js`, `src/vehicle-pbr.js`
- `src/audio.js`, `src/progress.ts`, `src/stage-catalog.ts`

Verified from source and repository documentation:
- Browser racing runtime with acceleration, braking, steering, off-road handling and race progression.
- Multi-touch input architecture, separate touch ownership and gyro/tilt steering helpers.
- Vehicle dynamics and tire/grip calculations, collision/damage/destruction systems.
- NPC race traffic, pickups, race stages/world themes, showroom and 3D race rendering.
- Local browser persistence for player progress/settings (the existing race save is not a city-save implementation).
- Offline-oriented local assets and service-worker asset caching.

Important boundary: existing race traffic AI and race progression are not evidence of a general city road graph, pedestrian simulation, zoning, city economy or municipal services.

### 3.2 Cocos Creator source integration

The repository declares Cocos Creator 3.8.6 and contains these Cocos-facing scripts:
- `assets/scripts/MshinGame.ts`
- `assets/scripts/VehicleController.ts`
- `assets/scripts/WorldRenderer.ts`
- `assets/scripts/ProgressStore.ts`
- `assets/scripts/VehicleDamageRenderer.ts`
- shared TypeScript core: `src/cocos-core.ts`

**Blocking audit finding:** `assets/scenes/` contains only `.gitkeep`; there is no serialized `.scene` file in the audited tree. Existing project documentation explicitly says the browser runtime is an independent Canvas/WebGL implementation and is not a Cocos export. It also says the Cocos scripts have source/syntax validation only and that Editor Preview, engine-aware validation, Web build and Android build have not yet been proven.

Therefore:
- Cocos Creator 3.8.6 is the declared target engine.
- Cocos source files exist.
- A launchable Cocos scene/build is **not verified**.
- A browser success must not be described as a Cocos build success.

### 3.3 Assets and content

The tree contains `assets/resources`, `assets/vector`, `assets/scenes`, `cdn/assets`, `cdn/previews`, `icons` and local asset manifests. The scene folder has no scene asset. Existing race scenery and vector art are useful as legacy content, but there is no evidence yet of a production-ready city asset library (buildings, roads, citizens, street furniture, public services).

No newly generated external 3D asset has been accepted by this audit. Every future asset must pass a documented art-direction, topology/UV/material, scale, collision, file-size and runtime performance gate before being committed.

## 4. Quality and CI baseline

At audit time the latest observed `main` push was commit `cfa1168208436eb40a5340379c7aa56078d5b0f5`.

Latest observed Actions outcomes for that commit:
- `Validate Mshin game data and portable TypeScript core`: **success**
- `pages build and deployment`: **success**
- `Mshin desktop and mobile browser smoke`: **failure**

### 4.1 Exact latest browser-smoke failure

Workflow run: [41416733743](https://github.com/pasoooir/Mshin/actions/runs/41416733743)  
Job: `browser-smoke` (job ID `125182302009`)  
Failing assertion: `tests/browser-smoke.mjs:260`  
Message: `game loop must not stall for multiple seconds in smoke run`

The diagnostic reported:
- `maxFrameMs = 5321.6 ms`
- `maxDrawCostMs = 5321.6 ms`
- `maxLoopCostMs = 5321.6 ms`
- `maxUpdateCostMs = 5.2 ms`
- `maxAudioCostMs = 0.4 ms`
- `trackCacheBuilds = 0`
- `trafficCount = 6`

The server startup succeeded; the browser test ran and failed on the runtime performance assertion. The captured telemetry points to a single very long draw/loop frame, not a server startup failure. Root cause still requires profiling the exact draw path; do not weaken or delete the assertion to make CI green.

### 4.2 Follow-up CI diagnosis — 2026-11-02 10:37 UTC

Renderer PR #136 was re-run after the bounded-upload change. Browser smoke run 41428176634 failed at tests/browser-smoke.mjs:396 with only two sampled framebuffer colors, despite a live WebGL context and zero GL errors. Telemetry showed trackBuildProgress=0.916. The renderer retained partially uploaded meshes in pendingTrackParts but drew only completed road/decor arrays. The early gameplay frame therefore showed only the clear color until the replacement track finished building.

A follow-up correction was committed to PR #136:
- draw pendingTrackParts while the track is being assembled;
- switch to completed road/decor arrays after build completion;
- add a regression assertion requiring progressive geometry to be drawn.

Commit: 6128c2c3b0070182b157af94607eb57215338eb8. Portable validation passed; browser-smoke run 41430262465 was still in progress at this follow-up. The fix is not yet accepted until browser smoke passes.

### 4.3 Workflow inventory

The default branch has three focused workflows:
- `.github/workflows/browser-smoke.yml`
- `.github/workflows/validate-game-data.yml`
- `.github/workflows/vendor-runtime-assets.yml`

The latest observed data/core validation passed. Browser smoke remains a P0/P1 quality gate. GitHub Pages deployment completed successfully for the inspected main commit; this only proves the static deployment pipeline, not full gameplay or Cocos readiness.

## 5. Pull request and branch audit

The GitHub API returned **22 open PRs** in the follow-up inspection at 2026-11-02 10:37 UTC (the initial phase-zero snapshot recorded 20). They include:
- PR #132: tenfold track length and mobile steering correction (open, base `main`, CI on its head: core validation passed; browser smoke failed).
- PRs #99, #107, #108, #110–#117 and #62, #65, #74, #89, #92–#94, #102: racing physics, controls, smoke driver, track environment, camera, menu and input work.
- Many are stacked on other feature branches rather than directly targeting `main`; several are drafts.

Do not bulk-merge or close these PRs. Each requires base/head/diff/CI/dependency review. Stacked PRs must be reviewed in dependency order. PR #132 is the clearest current candidate for focused follow-up because it addresses a directly user-reported driving-control/track-length issue, but its browser CI is not green.

## 6. Reusable systems and integration opportunities

| Existing capability | Sims City reuse path | Required work before acceptance |
|---|---|---|
| Vehicle dynamics and tire model | Player free-drive vehicle | Adapt to city-road coordinates, speed limits, intersections and collisions; regression tests |
| Multi-touch / gyro input | Driving mode and mobile city camera controls | Separate input contexts; prevent city/driving focus conflicts |
| 3D race renderer and vehicle PBR | Vehicle rendering and visual reference | Extract reusable renderer boundaries; city-scale batching/LOD/culling |
| Traffic AI | Initial vehicle behavior reference | Replace track-following assumptions with road-graph routing and lane/ junction state |
| Stage/world catalog | City scenario/theme seed data | New city-world schema; don't conflate race stages with city maps |
| Progress persistence | Player profile/progression inspiration | Versioned, per-city save format with migration and corruption recovery |
| Audio and asset pipeline | City ambience, traffic and service audio | Spatial audio and lifecycle/performance tests |
| TypeScript core and Node tests | Deterministic city simulation modules | Domain boundaries, seeded simulation, unit/integration tests |

## 7. Missing Sims City capabilities

No verified implementation was found in the audited repository for:
- City grid/terrain editing, parcels, zoning, road construction/editing or road network graph.
- Building placement, construction lifecycle, occupancy, upgrades or demolition.
- Households, citizen schedules, population growth, jobs, education or happiness.
- City budget, taxes, supply/demand, markets, trade or business inventory.
- Power, water, sewage, waste, police, fire, healthcare or education service networks.
- Pedestrian routing, public transport, parking, city-wide traffic assignment or junction control.
- City missions tied to simulation state.
- Multi-city save/load with schema versioning and migrations.
- A completed city UI or a playable city vertical slice.

These are **not implemented/verified**, not merely “hidden” by the existing race menu.

## 8. Technical risks and architecture recommendations

1. **Runtime split:** avoid duplicating the domain model between browser and Cocos. Put simulation rules in engine-independent TypeScript modules; write thin browser and Cocos adapters.
2. **Coordinate-system risk:** define one documented world-space convention and explicit adapters for current race coordinates, city grid coordinates and Cocos coordinates.
3. **Road-network dependency:** road graph and lane/junction topology must precede general traffic and service vehicle dispatch.
4. **Simulation scale:** use deterministic fixed simulation ticks and multi-tier citizen/vehicle simulation; rendering population must not define simulated population.
5. **Persistence risk:** introduce a versioned city-save schema before adding persistent city entities. Keep existing race progress keys/data intact.
6. **Cocos readiness:** create and validate a real startup scene in Creator 3.8.6; do not infer engine readiness from TypeScript syntax checks.
7. **Performance risk:** profile the existing 5.3-second draw stall before layering city-scale rendering on top.
8. **Asset quality:** require professional plugin-assisted concept/design/model workflows, but only accept outputs that pass measurable runtime and art QA. Tool use is not a substitute for asset validation.
9. **IP risk:** create original art and naming; use competitor research only for high-level mechanics and public user feedback.

## 9. Plugin/tool availability observed in this session

The current ChatGPT tool surface exposes integrations/capabilities for GitHub, Context7, Amazing Drawing, OpenArt, Runchat, Figma, Canva, SketchMonkey Design Studio, and the Build 3D Game Rooms workflow skill. These are available tool surfaces, not proof that every external desktop bridge or paid generation service is currently running or authorized.

- GitHub: repository inspection, branches, files, PRs, CI logs and commits.
- Context7: resolved the exact /cocos/cocos-engine/3.8.6 library. Retrieved excerpts were limited to engine error/configuration references, so each API still requires verification against official 3.8.6 documentation.
- Amazing Drawing: suitable for city/block/road-network diagrams.
- OpenArt: connected, but the account balance reported 0 credits; image generation was not run.
- Build 3D Game Rooms: structured concept-to-asset-to-runtime workflow; requires its prescribed gates and reference documents before execution.
- Runchat: connected, but no existing runchats/workflows were returned in the current account. Rhino/Blender bridge availability must be checked at execution time.
- Figma: authenticated with a View seat on the Starter team; a FigJam runtime architecture diagram was generated. Canva: connected; no marketing artifact is required yet.
- SketchMonkey Design Studio: industrial/CMF concept exploration where relevant.
- UI/UX Designer and Product Design connectors were not present in the current tool list. Meshy and Contour3D were not present as direct tool namespaces.
- Sketchy Medical tools are present, but medical-reference use is not currently on the critical path.

## 10. Phase-zero exit criteria

- [x] Repository metadata and default branch inspected.
- [x] Recursive source tree inspected.
- [x] Package, declared engine/toolchain and test commands inspected.
- [x] Existing race and Cocos source boundaries inspected.
- [x] Cocos scene folder inspected; no serialized scene found.
- [x] Latest Actions run and failing browser-smoke job logs inspected.
- [x] Open PR inventory inspected.
- [x] Current-session design/tool surfaces inventoried.
- [ ] Full PR dependency/diff review and acceptance of the renderer fix after browser smoke passes.
- [ ] Editor-opened Cocos scene and engine-aware Web build verification.
- [ ] Competitor research and public community-feedback synthesis.
- [ ] Approved city art direction and first professionally produced asset pack.

**Audit conclusion:** the repository is a valuable racing-game foundation, but Sims City is a new product layer that must be built on top of it. The first technical work should stabilize the current browser runtime and establish a deterministic city-domain core without damaging the existing driving game.
