# MSHIN — City Design Package Readiness & Cross-Document Traceability Audit

- Audit date: 2026-11-03
- Repository: `pasoooir/Mshin`
- Design branch: `docs/city-master-game-design`
- Status: design governance audit; **not implementation authorization and not approval of the V1 package**.
- Platform authority: Android/iOS, mobile-first; Cocos Creator 3.8.6 target.
- Scope: section-46 readiness, canonical catalog/registry authority, cross-domain dependencies, unresolved document wording, and evidence needed before a city-building implementation gate can be considered.

## 1. Executive decision

**The section-46 gate is still NOT READY. Do not start or expand city-building implementation.**

The design library is extensive and now covers spatial layout, roads/transit, fleet/freight, utilities, finance, trade, housing/education, citizen needs, crisis management, tourism, weather and visual production. However, breadth of documentation is not proof that the end-to-end V1 design is complete, approved, calibrated, implemented or accepted.

The current master document explicitly records section 46 as incomplete and states that city-building coding has not begun. The existing browser city prototype and its tests must not be represented as the approved Cocos city-building vertical slice.

This audit records readiness gaps and document ambiguities only. It does not change catalog IDs/statuses, numeric balance, save schemas, gameplay behavior, V1 scope or implementation authorization.

## 2. Section-46 readiness matrix

| Section-46 requirement | Evidence in design library | Readiness | Evidence still required |
|---|---|---|---|
| One defined sample region: map, climate, resources, architecture | Capital world spatial spec; visual and environment atlases | **Partial** | Approved map-layout sheet with actual geography, boundaries, terrain/resource placements, climate assumptions and architecture references |
| V1 building and recipe catalog | V1 content catalog and item/recipe registry exist | **Partial** | Review/approval, complete ID-to-recipe coverage, final schema references, balance rationale and acceptance scenarios; unresolved values stay TBD |
| Complete road, housing, household, production, warehouse and service loop | Spatial, fleet, utility, housing and service specs exist | **Not demonstrated** | One coherent causal flow with named authoritative owners, command/tick order, inputs/outputs, failure/recovery and ledger effects |
| At least one raw-material-to-consumption chain | Item/recipe registry describes item and recipe contracts | **Not demonstrated** | One fully specified, calibrated, executable chain with reservation, workforce/utility constraints, storage limits, delivery/consumption and idempotent accounting |
| Base economy, budget and cash flow | Municipal finance proposal and catalog references | **Partial / proposal only** | Approved V1 finance subset, accounts/ledger, opening balances, build/upkeep/production costs, affordability, insolvency/shortage behavior and reconciliation scenarios |
| Traffic/fleet at three fidelity levels | Fleet/freight spec defines aggregate, sampled and focused tiers | **Design outlined** | Approved V1 subset, route graph contract, tier-switch invariance, dispatch/cargo lifecycle and deterministic test evidence |
| Save, recovery and offline simulation | Cross-document requirements exist | **Not demonstrated** | Versioned production save contract, migration, crash recovery, offline catch-up determinism, duplicate prevention and round-trip acceptance |
| Mobile HUD, building panel, heatmap and build tools | Mobile UX spec and visual benchmark define requirements | **Partial** | Approved screen/state inventory, interaction flows, one-handed/safe-area checks, touch acceptance and functional data ownership |
| Visual bible and representative model/material/animation quality | Visual north star, asset bible, building and mobility visual atlases exist | **Design direction exists** | Editable production assets/prefabs, provenance/license, mesh/UV/PBR/LOD review, Cocos integration, animation state links and reviewed captures |
| Acceptance scenarios and real-device performance budgets | Several specs list acceptance tests; budgets intentionally TBD | **Not demonstrated** | End-to-end test suite, supported-phone matrix, actual device captures/profiles and measured FPS/memory/draw-call/triangle results |

**No row above is marked complete.** This is deliberate: document presence is not equivalent to review approval, working implementation or evidence.

## 3. Canonical authority and status preservation

### 3.1 Single authority rules

1. `CAPITAL_REGION_V1_CONTENT_CATALOG.md` is the sole authority for building/infrastructure IDs and V1 status.
2. `CAPITAL_REGION_V1_ITEM_RECIPE_REGISTRY.md` is the canonical authority for item IDs, units and recipe transformations.
3. `CAPITAL_REGION_WORLD_SPATIAL_SPEC.md` is the spatial authority for terrain, grid/world transform, parcels, frontage and road graph.
4. `VEHICLE_FLEET_FREIGHT_TRAFFIC_SPEC.md` is the authority for vehicle/trip/dispatch/freight behavior.
5. Domain atlases may detail future architecture but cannot create operational IDs, change status, introduce balance values or authorize implementation.
6. Visual documents describe presentation and asset delivery; they cannot create gameplay connectivity, capacity, population, service or economic effects.

### 3.2 Statuses explicitly preserved

- `INF-ROAD-LOCAL`, `INF-ROAD-INTERSECTION`: V1-Required.
- `RES-HOUSE-STARTER`, `RES-HOUSE-FAMILY`: V1-Required.
- `IND-FACTORY-BASIC`, `COM-WORKSHOP-BASIC`, `LOG-WAREHOUSE-STARTER`: V1-Required.
- `UTL-POWER-PLANT-SMALL`, `UTL-WATER-PUMP`, `UTL-SEWAGE-PLANT`: V1-Required.
- `ENV-WASTE-DEPOT`, `SVC-FIRE-STATION-SMALL`, `SVC-POLICE-POST`, `SVC-CLINIC`, `GOV-CITY-HALL`, `GOV-CONSTRUCTION-OFFICE`, `TRADE-DEPOT`: V1-Support.
- `INF-ROAD-UPGRADED`, `LOG-FREIGHT-TERMINAL`, education and other candidate entries remain Candidate.
- `INF-ROAD-BRIDGE`, `VEH-BUS`, public transport, airport/port, tourism/landmarks, advanced research and other deferred entries remain Deferred.
- Public parking, highways, transit stops/lines/terminals, bus lanes and adaptive signals still lack approved operational catalog IDs.

No ID or status was added, renamed, promoted or demoted by this audit.

## 4. Cross-document wording reconciliation

The audit identified two wording ambiguities. They have now been corrected in `CAPITAL_REGION_V1_CONTENT_CATALOG.md` (commit `83673d79eb0d1fbcbb0e3c2f5839639d0219548a`), preserving every existing ID and status.

### 4.1 Catalog-approved utility facilities versus unapproved network assets

The catalog explicitly lists:
- `UTL-POWER-PLANT-SMALL` as V1-Required;
- `UTL-WATER-PUMP` as V1-Required;
- `UTL-SEWAGE-PLANT` as V1-Required;
- `ENV-WASTE-DEPOT` as V1-Support.

The catalog wording now explicitly preserves those exact entries while distinguishing them from unapproved additional substations, generation types, transmission/distribution assets, water/sewer graph components, additional waste facilities and maintenance depots. Facility status does not by itself complete or approve a network topology or full service simulation.

### 4.2 Catalog-approved support services versus future emergency-service proposal

The catalog explicitly lists `SVC-FIRE-STATION-SMALL`, `SVC-POLICE-POST` and `SVC-CLINIC` as V1-Support; the fleet registry lists the corresponding fire engine, police car and ambulance classes as V1-Support.

The catalog wording now preserves those exact entries while distinguishing them from unapproved hospitals, additional facilities/vehicle classes, burglary simulation, sirens, emergency-priority traffic, incident/disaster classes and expanded emergency simulation.

### 4.3 Existing prototype behavior versus spatial specification — unresolved design/implementation gap

The spatial spec requires explicit terrain metadata, stable parcel IDs, a versioned grid/world transform, multi-cell atomic footprints, frontage/access anchors and an authoritative road graph. The current browser prototype uses a 32×32 tile state, a separately generated 64×64 renderer grid, orthogonal road adjacency and Euclidean service distance.

The current browser implementation must remain classified as a prototype/visual vertical slice, not as conformance to the spatial production contract. Preserve the existing safety guards and do not add ROW/sidewalk, crossings, street furniture or new simulation until the section-46 and spatial design gates are approved.

### 4.4 Proposal documents and catalog authority — ongoing governance rule

Finance, trade, tourism, weather, education/wellbeing, citizen needs, crisis management and utilities documents are proposals/future-facing specifications. Their entities, fields, IDs used as discussion labels, example rates and process descriptions must not silently become production schema or V1 content.

Every implementation handoff must point to the exact catalog-approved ID/status and the approved subset of the domain specification. Proposal-only sections remain non-operational.

## 5. Dependency traceability that must be completed before implementation

| End-to-end capability | Required authoritative dependency chain | Required failure/recovery evidence |
|---|---|---|
| Building placement | Terrain/buildable parcel → footprint/rotation → zoning → explicit frontage/access → unlock/cost → atomic placement | Occupancy, invalid terrain, locked plot, no frontage, disconnected road, failed payment and rollback |
| Household occupancy | Approved residential definition → usable capacity → household cohort rule → utility/service availability | No automatic population on placement; capacity, move-in/out and save/load consistency |
| Production | Recipe registry → input reservation → workforce/utilities → simulation clock → output reservation/capacity → inventory ledger | Missing input, blocked output, pause/cancel, duplicate tick/replay and process death |
| Freight delivery | Stock reservation → destination capacity reservation → compatible vehicle → route/graph version → load/trip/unload → ledger | Full destination, closure/reroute, cancellation, duplicate completion and cargo custody |
| Municipal services | Catalog-approved facility → operational state → network connectivity → staffing/inventory/budget → route and effective capacity → delivered service | Disconnected, under-capacity, unavailable, degraded, maintenance and recovery |
| Municipal finance | Budget authority → cash/commitment/reservation → posted ledger event → reconciliation | Insufficient funds, retry/idempotency, save/load and offline replay |
| Visual representation | Authoritative entity/state → asset key/prefab → provenance/license → LOD/material/animation → Cocos scene | Missing asset, unknown state, stale graph version, reduced LOD and no gameplay side effects |
| Mobile interaction | Approved screen/state → touch command → validation result → authoritative state → accessible feedback | Safe-area, small viewport, touch cancellation, gesture conflict and disabled/unknown state |

The table defines required traceability, not permission to implement these systems now.

## 6. Required package deliverables still outstanding

1. **Approved Capital map layout sheet:** coordinates and boundaries, terrain/water/resource metadata, initial and locked parcels, road nodes/edges, frontage, utility reserve, industrial/residential relationship and freight entry.
2. **V1 catalog/recipe approval record:** explicit approval state, schema versions, complete reference validation, unresolved decisions and non-invented TBD values.
3. **V1 end-to-end sequence specification:** deterministic simulation tick order and command/event ownership across placement, households, production, inventory, freight, utilities, services and finance.
4. **Economy calibration workbook/scenarios:** source/rationale/version for each value; no arbitrary balance defaults.
5. **Save/offline contract:** authoritative schema, migrations, idempotency, crash recovery, replay and offline equivalence.
6. **Mobile UX acceptance pack:** screen inventory, touch flows, build/inspect modes, overlays/legends, accessibility and smallest supported viewport.
7. **Production visual sample pack:** specialist-tool editable source files, mesh/UV/PBR/LOD, prefab, animation/state binding, commercial-use license/provenance and Cocos captures.
8. **Real-device acceptance pack:** named supported phone models, build identity, reproducible scenarios, captures, performance profiles and measured budgets.

## 7. Non-negotiable implementation hold

Until section 46 is explicitly approved:
- Do not add or expand the city simulation, production/economy, utility graphs, transit, emergency incidents, pedestrian graph, new road classes, ROW/sidewalk, public parking or new V1 IDs.
- Do not convert Candidate/Deferred/proposal concepts into active gameplay.
- Do not use visual props, fake metrics, proximity-only service radii or animation to imply operational capability.
- Do not invent dimensions, prices, capacities, rates, time constants, performance budgets or device support.
- Do not claim Cocos production readiness, real-phone acceptance or final visual quality without artifacts and evidence.
- Do not merge to `main`, publish, or change release scope as part of this audit.

Safe work remains limited to design consistency, traceability, source audits, documentation corrections, and regression protection for already existing behavior.

## 8. Source documents reviewed

- `docs/CITY_GAME_DESIGN_MASTER.md` — sections 46, 47, 59, 60 and 69.
- `docs/CAPITAL_REGION_V1_CONTENT_CATALOG.md`.
- `docs/CAPITAL_REGION_V1_ITEM_RECIPE_REGISTRY.md`.
- `docs/CAPITAL_REGION_WORLD_SPATIAL_SPEC.md`.
- `docs/CAPITAL_REGION_MAP_LAYOUT_DECISION_REGISTER.md` (structured decision template; map values remain TBD).
- `docs/VEHICLE_FLEET_FREIGHT_TRAFFIC_SPEC.md`.
- `docs/CAPITAL_REGION_PUBLIC_TRANSPORT_AND_ROAD_INFRASTRUCTURE_ATLAS.md`.
- `docs/CAPITAL_REGION_ESSENTIAL_CITY_SERVICES_AND_UTILITIES_ATLAS.md`.
- `docs/CAPITAL_REGION_MUNICIPAL_FINANCE_TAXATION_BUDGETING_AND_GOVERNANCE_SPEC.md`.
- `docs/CAPITAL_REGION_MARKET_TRADE_SUPPLY_CHAIN_AND_INTERREGIONAL_COMMERCE_SPEC.md`.
- `docs/CAPITAL_REGION_CITIZEN_NEEDS_SATISFACTION_AND_CITY_FEEDBACK_SPEC.md`.
- `docs/CAPITAL_REGION_EDUCATION_RESEARCH_HOUSING_AND_CITY_WELLBEING_ATLAS.md`.
- `docs/CAPITAL_REGION_DISTRICT_RESOURCE_ALLOCATION_AND_CRISIS_MANAGEMENT_SPEC.md`.
- `docs/CAPITAL_REGION_TOURISM_VISITORS_ATTRACTIONS_AND_HOSPITALITY_SYSTEM_SPEC.md`.
- `docs/CAPITAL_REGION_WEATHER_SEASONS_DAY_NIGHT_AND_ENVIRONMENTAL_IMPACTS_SPEC.md`.
- `docs/CAPITAL_REGION_EMERGENCY_SERVICES_FIRE_POLICE_HEALTH_AND_DISASTER_RESPONSE_SPEC.md`.
- `docs/CAPITAL_REGION_URBAN_ENVIRONMENT_AND_STREET_LIFE_ATLAS.md`.
- `docs/VISUAL_DEVELOPMENT_3D_ASSET_BIBLE.md`, `docs/MSHIN_VISUAL_NORTH_STAR_AND_GRAPHICS_QUALITY_MANDATE.md`, `docs/MOBILE_CITY_VISUAL_BENCHMARK_SPEC.md`, `docs/MOBILE_CITY_UX_INTERACTION_ACCESSIBILITY_SPEC.md`.

**Conclusion:** the design package has broad coverage but is not yet a complete, approved, evidence-backed vertical-slice specification. Resolve the two wording ambiguities in section 4, finish the section-46 deliverables and obtain explicit approval before city implementation resumes.
