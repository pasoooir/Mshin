# Sims City — Feature Matrix

**Status values:** ⬜ شروع‌نشده · 🟡 در حال اجرا · 🟢 تکمیل‌شده و تأییدشده · 🔴 شکست‌خورده یا مسدود  
**Rule:** all gameplay features start as not started. A document, mock-up, commit or successful workflow does not satisfy runtime acceptance.

| Feature ID | Feature | Purpose / acceptance criteria | Priority | Dependencies | Status | Test / evidence | Target |
|---|---|---|---|---|---|---|---|
| SC-CORE-001 | Deterministic simulation clock and root state | Immutable versioned city state, seeded PRNG, fixed ticks, pause/1x/2x/4x controls and bounded catch-up without dropped ticks | P1 | None | 🟡 | PR #137 commit 98b4c7b: 238 tests pass, 0 fail in portable suite; browser smoke queued; city gameplay acceptance not yet complete | VS |
| SC-WORLD-001 | World grid and parcels | Selectable buildable/non-buildable cells; coordinate round-trip | P1 | CORE | ⬜ | Grid, terrain and boundary tests | VS |
| SC-TERR-001 | Terrain data | Height, slope and water constraints affect build validation | P2 | WORLD | ⬜ | Terrain rule tests | v0.2 |
| SC-ROAD-001 | Road drawing | Straight/polyline placement preview, costs, snapping, obstacle and connection validation | P1 | WORLD | ⬜ | Road geometry and transaction tests | VS |
| SC-ROAD-002 | Road graph | Directed nodes/edges, lane direction, turns, speed, closure and access | P1 | ROAD-001 | ⬜ | Graph connectivity/path tests | VS |
| SC-ZON-001 | Zoning | Residential/commercial/industrial/public/green parcels with demand rules | P2 | WORLD, ROAD | ⬜ | Zoning validation tests | VS |
| SC-BLD-001 | Building lifecycle | Data-driven placement, construction, occupancy, operation, upgrade and demolition | P1 | ROAD, ZON | ⬜ | Placement and lifecycle tests | VS |
| SC-CIT-001 | Households and population | Homes, household composition, citizen identities and population totals | P2 | BLD | ⬜ | Population invariants | VS |
| SC-JOB-001 | Jobs and education | Job slots, employment assignment, school access and commute generation | P2 | CIT, BLD | ⬜ | Assignment and access tests | v0.3 |
| SC-BIZ-001 | Business simulation | Inventory, capacity, labor, input/output goods and operating state | P2 | BLD, ROAD | ⬜ | Supply/production tests | VS |
| SC-ECO-001 | City budget and tax | Ledger, income, upkeep, tax rates, solvency and clear accounting | P1 | BLD | ⬜ | Ledger invariants and tax tests | VS |
| SC-SRV-001 | Municipal service foundation | Coverage, capacity, budget and response-time effects | P2 | ROAD, BLD | ⬜ | Coverage and capacity tests | VS |
| SC-TRF-001 | NPC road traffic | Legal graph routes, congestion cost, lane/junction state and despawn policy | P2 | ROAD-002 | ⬜ | Deterministic route and integration tests | VS |
| SC-PED-001 | Pedestrian simulation | Sidewalk graph, safe crossings and destination scheduling | P3 | ROAD-002, CIT | ⬜ | Walkability tests | v0.5 |
| SC-PT-001 | Public transport | Stops, routes, capacity, timetable and transfer behavior | P3 | ROAD-002, CIT | ⬜ | Service/route integration tests | v0.7 |
| SC-DRV-001 | Player city driving | Existing Mshin vehicle controls and dynamics operate on city roads | P2 | ROAD-002 | ⬜ | Browser/mobile driving acceptance | VS |
| SC-MIS-001 | City-linked missions | Mission outcomes mutate authoritative economy, inventory or service state | P2 | ECO, DRV | ⬜ | Mission-state integration tests | VS |
| SC-SAV-001 | Versioned city saves | Multi-city local save, validation, recovery and migration | P1 | CORE | ⬜ | Round-trip/corruption/migration tests | VS |
| SC-UI-001 | City management UI | Build, inspect, overlays, budget and time controls invoke real systems | P2 | WORLD, ROAD, BLD | ⬜ | Browser interaction tests | VS |
| SC-ENV-001 | Day/night and weather | Environment state affects lighting and selected simulation variables | P3 | CORE | ⬜ | Deterministic environment tests | v0.6 |
| SC-ART-001 | Professional city asset library | Consistent buildings, road kit, props, citizens and vehicles pass engine QA | P2 | Art direction | ⬜ | Asset manifest + import + visual review | VS |
| SC-PERF-001 | Adaptive performance | Measured budgets, LOD, pooling, culling and simulation tiers | P1 | Rendering baseline | ⬜ | Small/medium/large-city benchmarks | v0.8 |
| SC-COCOS-001 | Cocos startup scene | Real serialized scene launches in Creator 3.8.6 and Web build works | P1 | Cocos adapter | ⬜ | Editor Preview + Web build artifact | v0.4 |

## Required evidence fields for implementation PRs

Each feature implementation PR must add/update:
- source files and data schema;
- unit and integration tests;
- browser acceptance scenario where applicable;
- before/after performance evidence for runtime-sensitive changes;
- screenshots or capture of actual in-game behavior for visual changes;
- acceptance notes and known limitations;
- exact CI run and commit SHA.

## Version target definitions

- **VS:** first integrated browser-playable city vertical slice.
- **v0.2:** terrain, roads, zoning and building lifecycle.
- **v0.3:** population, jobs and economy.
- **v0.4:** traffic and driving integration.
- **v0.5:** municipal services and pedestrian foundation.
- **v0.6:** visual environment, day/night and weather.
- **v0.7:** public transport, tourism, trade and events.
- **v0.8:** performance and scale hardening.
- **v0.9:** full beta acceptance.
- **v1.0:** release candidate after explicit release approval.
