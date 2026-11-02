# Sims City — Technical Architecture

## 1. Architecture decision

Use an engine-independent TypeScript simulation core with thin presentation/runtime adapters:
- **Domain core:** deterministic state transitions, entities, rules, pathfinding and persistence schemas.
- **Browser adapter:** retain current Canvas/WebGL racing experience while introducing city rendering/UI incrementally.
- **Cocos adapter:** Creator 3.8.6 components, scenes, input and asset loading; no domain rules duplicated in components.
- **Tooling/QA:** Node tests, Playwright browser acceptance, asset validation and Cocos Editor build checks.

The current repository has no serialized Cocos scene. The browser game is not a Cocos export. The architecture must preserve that distinction until Creator verification exists.

## 2. Layer boundaries

| Layer | Owns | Must not own |
|---|---|---|
| Domain | CityState, entities, commands, simulation ticks, invariants | Cocos Node, DOM, Canvas, WebGL objects |
| Application | Use cases, command validation, event dispatch, save orchestration | Rendering and engine lifecycle |
| Infrastructure | Local storage adapter, serialization, asset manifests, deterministic RNG | City policy decisions |
| Presentation | City view, overlays, HUD, touch controls, selection and feedback | Authoritative economy/population mutation |
| Engine adapters | Cocos lifecycle, nodes/components, browser renderer integration | Duplicate simulation algorithms |

## 3. Module map

Suggested domain modules (create only as dependencies require):
- `src/city/core/`: identifiers, clock, seeded RNG, event contracts, validation.
- `src/city/world/`: map, grid, parcels, terrain.
- `src/city/roads/`: road geometry, graph, lanes, junctions, access.
- `src/city/buildings/`: definitions, placement, construction, occupancy.
- `src/city/citizens/`: households, schedules, jobs, needs and population.
- `src/city/economy/`: ledger, tax, business, goods and budget.
- `src/city/services/`: utility networks and municipal service coverage.
- `src/city/mobility/`: routing, vehicles, pedestrians, transit and parking.
- `src/city/missions/`: mission state and city-effect commands.
- `src/city/persistence/`: versioned city save, validation and migrations.
- `src/city/application/`: commands/use cases and orchestration.
- Existing `src/vehicle-dynamics.js`, `src/multitouch-input.js`, `src/traffic-ai.js` remain legacy modules until explicit adapters and regression tests are implemented.

Do not create empty directories for every named subsystem. Add a module when a vertical-slice use case needs it.

## 4. Authoritative state and event flow

UI emits a typed command → application validates permission/preconditions → domain transaction applies state change → domain emits immutable event(s) → projections/overlays update → save adapter persists committed state.

Examples:
- `PlaceRoadCommand` → validate endpoints, terrain, collisions, funds → add road graph edges → `RoadPlaced` → recompute parcel access and route cache.
- `AdvanceSimulationTick` → update scheduled trips, businesses, services and ledger in deterministic order → `SimulationTickCompleted`.
- `CompleteDeliveryMission` → validate route/mission state → update business inventory and player reward → `DeliveryCompleted`.

Failed commands must be side-effect free and return structured reason codes.

## 5. Coordinates and geometry

- Define one world unit convention and coordinate handedness in a shared `WorldCoordinate` module.
- Grid coordinates are integer cell indices; parcels own polygonal footprint/valid placement regions.
- Road geometry is continuous polyline/spline data, but routing topology is a graph of explicit junction/connection nodes and directed lane edges.
- Vehicle physics uses continuous world-space positions and velocities; route following maps graph paths to lane centerline segments.
- Centralize conversion to Cocos coordinates. Never scatter sign flips or unit multipliers through renderers.
- Unit tests must cover grid↔world round trips, road snapping, junction connectivity and driving heading conventions.

## 6. Simulation scheduling

- Fixed tick independent of render FPS; start with a measured, configurable simulation tick.
- Use stable update phases: time/schedules → route requests → mobility → citizen state → business/production → services → economy ledger → derived metrics/events.
- Use deterministic seeded randomness; do not call ambient Math.random inside domain logic.
- Route recomputation is event-driven and cached; invalidate only affected regions/edges.
- NPCs use simulation tiers: near = full movement/decision; mid = simplified route/state; far = statistical trip/flow updates.
- Rendering interpolates between simulation snapshots; it never mutates authoritative state.

## 7. Road and traffic architecture

Road geometry and graph topology are separate concepts:
- Geometry: visible centerline, width, lanes, sidewalk and construction cost.
- Graph: directed lane edges, junction movements, turn restrictions, speed limits and access.
- Traffic flow: route choice, lane selection, headway, signal phases, congestion and incidents.
- City services and player missions use the same routing API with vehicle-class constraints.
- Existing race traffic is not reused as a city route solver; it is a behavioral/animation reference only.

## 8. Persistence

Save envelope:
- `schemaVersion`
- `gameVersion`
- `cityId`, `cityName`, `createdAt`, `savedAt`
- deterministic seed and simulation tick
- normalized entity records and indexes
- optional checkpoint/checksum metadata

Requirements:
- Validate before applying loaded data.
- Write to a new slot/temp key, verify serialization, then atomically promote where storage permits.
- Keep rotating backup slots; do not overwrite the last known-good save on failed writes.
- Migrations are pure functions `vN -> vN+1`, each with fixture tests.
- Multiple cities use independent slots.
- Preserve existing Mshin race progress/settings keys and behavior.

## 9. Cocos Creator 3.8.6 integration

- Build a real serialized startup scene and attach thin components to scene nodes.
- Use engine-supported `Component` lifecycle and `cc` imports according to Creator 3.8.6 documentation.
- Keep simulation modules importable without the Cocos engine so Node tests remain possible.
- Validate in the Creator Editor: asset import, scene open, Preview, Web build and runtime.
- Syntax/transpile checks do not count as an Editor build.
- Store generated/approved art in the correct `assets/` locations with importer metadata as required by Creator.

## 10. Error and observability model

- Structured domain error codes: `INSUFFICIENT_FUNDS`, `INVALID_TERRAIN`, `NO_ROAD_ACCESS`, `OCCUPIED_PARCEL`, `CAPACITY_EXCEEDED`, `NO_ROUTE`.
- Development diagnostics expose tick duration, route queue, entity counts, update phase cost, draw calls and memory where available.
- Performance regressions fail CI based on stable, repeated measurements; do not relax thresholds to hide stalls.

## 11. Security, offline and privacy

Core single-player city gameplay must not require a network account or transmit save data. Analytics are opt-in and must not contain personal data. Any future cloud sync requires explicit architecture and consent; no backend dependency is introduced into the offline vertical slice.

## 12. Architecture decision gates

1. Do not migrate the existing race runtime wholesale.
2. Do not make Cocos components authoritative domain stores.
3. Do not implement city traffic before road graph contracts are tested.
4. Do not add a new renderer until the current 5.3-second draw stall is profiled.
5. Do not add multiplayer or cloud persistence before local save integrity is proven.
