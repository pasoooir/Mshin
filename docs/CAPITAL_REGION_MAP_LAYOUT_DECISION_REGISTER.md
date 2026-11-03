# MSHIN — Capital Region V1 Map Layout Decision Register

- Version: 0.1.0-design
- Status: **Draft template — no geography, coordinate, resource, parcel, or gameplay decision is approved by this document.**
- Repository: `pasoooir/Mshin`
- Design authority: `CAPITAL_REGION_WORLD_SPATIAL_SPEC.md`
- Approval gate: section 46 of `CITY_GAME_DESIGN_MASTER.md`
- Target: Cocos Creator 3.8.6; Android/iOS; portrait-first mobile UX

## 1. Purpose and boundary

This register converts the spatial specification's requirement for a separate, approved map-layout sheet into a traceable decision package. It defines what must be supplied, how each decision is validated, and which authority owns it.

It deliberately contains no invented map dimensions, grid scale, coordinates, terrain values, resource deposits, parcel count, road width, cost, capacity, or performance target. Every unresolved value remains `TBD`.

This is a design-completion aid only. It does not approve V1 content, alter catalog IDs/statuses, authorize implementation, or replace section 46 approval.

## 2. Decision status vocabulary

Use only these states for each row:
- `TBD` — no evidence-backed proposal yet.
- `Proposed` — documented candidate, not approved.
- `Reviewed` — cross-document and technical review completed; approval still pending.
- `Approved` — explicit decision recorded by the project owner with date and evidence.
- `Rejected` — proposal rejected; rationale and replacement path recorded.

A row may not be marked Approved merely because a value appears in a concept image, generated map, prototype, code constant, or example in another document.

## 3. Map identity and coordinate contract

| Decision key | Required definition | Required evidence | Current value | Status |
|---|---|---|---|---|
| MAP-IDENTITY | Stable map definition ID and revision/version policy | Approved map identity and migration policy | TBD | TBD |
| MAP-BOUNDARY | Region boundary and playable/locked/outside classification | Top-down map sheet with coordinate references | TBD | TBD |
| GRID-DIMENSIONS | Grid width/height and coordinate origin | Reviewed grid overlay and placement tests | TBD | TBD |
| GRID-SCALE | Grid-to-world scale and unit convention | Cocos greybox measurement and camera review | TBD | TBD |
| GRID-TRANSFORM | Single authoritative grid↔world transform and version | Round-trip transform tests; migration implications | TBD | TBD |
| WORLD-ORIENTATION | Axis direction, north/orientation convention and rotation handedness | Map sheet legend and scene validation | TBD | TBD |
| CHUNK-PARTITION | Spatial chunking and streaming boundaries | Profiling evidence; no guessed chunk size | TBD | TBD |
| MAP-REVISION | Versioned map data and compatibility/migration behavior | Save/load and migration scenarios | TBD | TBD |

Grid/world/screen transforms must remain distinct. Persistent state stores grid-space positions and stable definition IDs, never camera-relative or screen-space positions.

### 3.1 Spatial schema, network revisions and persistence boundary

| Decision key | Required definition | Required evidence | Current value | Status |
|---|---|---|---|---|
| SPATIAL-SCHEMA-VERSION | Version of authoritative cell/terrain/parcel/access data schema, compatibility policy | Schema contract, fixtures and migration tests | TBD | TBD |
| ROAD-GRAPH-VERSION | Independent road/access graph revision and stale-route invalidation policy | Graph diff, route invalidation and save/reload tests | TBD | TBD |
| UTILITY-GRAPH-VERSION | Independent typed utility-network graph revision; separate from road/access graph | Typed topology contract, endpoint/direction/elevation tests and migration evidence | TBD | TBD |
| PEDESTRIAN-GRAPH-VERSION | Independent pedestrian graph revision only if pedestrian movement is explicitly approved for V1 | Approved scope, legal crossing/path fixtures and migration evidence | TBD | TBD |
| SERVICE-ACCESS-REVISION | Version/source identity for route-time and provider-capacity access results, if persisted or cached | Recalculation and invalidation tests against graph/provider changes | TBD | TBD |
| SAVE-MAP-COMPATIBILITY | Save schema ↔ map revision ↔ graph revision compatibility and migration ordering | Save/load, rollback, old-save and interrupted-migration tests | TBD | TBD |
| OFFLINE-SPATIAL-STATE | Which spatial/network state advances offline, freezes, or requires reconciliation | Approved offline simulation contract and deterministic time-step tests | TBD | TBD |

Road/access, typed utility and pedestrian graphs are separate authorities. A shared map coordinate system does not make their nodes, edges, permissions, routes or revisions interchangeable. Pedestrian graph rows remain conditional and do not authorize pedestrian features. Save migration must preserve stable IDs and must not silently reinterpret old coordinates or graph references.

## 4. Geographic composition and landform

| Decision key | Required definition | Required evidence | Current value | Status |
|---|---|---|---|---|
| NATURAL-FEATURE | Chosen river/lake/ridge/green corridor or explicit decision to omit | Reference board, map sheet, gameplay rationale | TBD | TBD |
| TERRAIN-CELLS | Terrain type coverage by cell/region | GIS-like source layer or authored data with provenance | TBD | TBD |
| ELEVATION | Elevation bands and datum | Elevation layer and consistency review | TBD | TBD |
| SLOPE | Slope classes and placement consequences | Derived slope map and placement test cases | TBD | TBD |
| WATER-BODY | Water geometry, banks, flow class only if simulated | Hydrology layer and source/provenance | TBD | TBD |
| WATER-EXCLUSION | Water clearance and flood exclusion rules | Spatial validation cases | TBD | TBD |
| HAZARD-TAGS | Explicit hazard tags and whether any are simulated in V1 | Approved rule source; no decorative hazard implication | TBD | TBD |
| PROTECTED-LAND | Protected/non-buildable land and reason | Map overlay and validation tests | TBD | TBD |

Terrain, slope, water and protected status must be authoritative data. They cannot be inferred from texture, mesh, color, or camera view.

## 5. Natural resources

Each deposit must have a stable data identity and explicit extraction contract. Do not create a resource deposit solely to make the map look varied.

| Decision key | Required definition | Required evidence | Current value | Status |
|---|---|---|---|---|
| RESOURCE-TYPES | Resource types permitted by approved V1 registry | Registry reference and catalog dependency | TBD | TBD |
| RESOURCE-LOCATIONS | Coordinates/footprints and terrain relationship | Resource overlay and source provenance | TBD | TBD |
| RESOURCE-RESERVES | Bounded reserve and unit | Calibrated extraction/consumption scenario | TBD | TBD |
| RESOURCE-EXTRACTION | Eligible building/recipe and extraction lifecycle | Approved recipe chain and acceptance test | TBD | TBD |
| RESOURCE-REGENERATION | Explicit no-regeneration or approved regeneration rule | Rationale and deterministic test | TBD | TBD |

If a resource type, building or recipe is not approved by the V1 catalog/registry, it cannot be activated by this map register.

## 6. Districts, parcels, ownership and expansion

| Decision key | Required definition | Required evidence | Current value | Status |
|---|---|---|---|---|
| DISTRICT-BOUNDARIES | District polygons and stable IDs, if districts are in V1 | Ownership/behavior distinction and UI map | TBD | TBD |
| DISTRICT-IDENTITY | Stable district IDs, lifecycle and map-revision compatibility | Registry, duplicate checks and save/load migration tests | TBD | TBD |
| LAND-OWNERSHIP | Owner/claim state for each parcel/cell and its authority, if modeled | Ownership transition rules and authorization/consistency tests | TBD | TBD |
| PARCEL-IDS | Stable parcel IDs and map-version relationship | Parcel table and duplicate/overlap checks | TBD | TBD |
| PARCEL-FOOTPRINTS | Exact cell sets, shape and rotation support | Footprint fixtures and atomic placement tests | TBD | TBD |
| BUILDABILITY | Per-cell buildable/protected/occupied/unlocked state | Terrain and parcel validation matrix | TBD | TBD |
| FRONTAGE | Explicit frontage edges and compatible road references | Graph/parcel topology checks | TBD | TBD |
| ACCESS-ANCHORS | Building access anchors and allowed vehicle/pedestrian modes | Building-family access contracts | TBD | TBD |
| EXPANSION-ORDER | Locked parcel sequence and prerequisites | Progression and save migration scenarios | TBD | TBD |
| EXPANSION-COST | Cost/resource/maintenance profile | Approved economy model and affordability tests | TBD | TBD |

District labels alone must not create buffs. Expansion must preview buildable area, natural constraints/resources, required road extension, network cost, maintenance and service gaps. No parcel count or cost is assumed here.

## 7. Road/access graph and freight approach

The road/access graph is separate from its rendered road mesh. The graph is also distinct from utility networks and any pedestrian graph. Each network type requires its own schema/revision, identity namespace, validation suite and route/cache invalidation rules; sharing coordinates does not imply shared connectivity.

| Decision key | Required definition | Required evidence | Current value | Status |
|---|---|---|---|---|
| ROAD-NODES | Stable node IDs, coordinates, intersection semantics | Graph export and topology validation | TBD | TBD |
| ROAD-EDGES | Stable edge IDs, endpoints, direction and lifecycle | Graph export, connectivity and dangling-node tests | TBD | TBD |
| ROAD-CLASSES | Exact approved V1 road classes and constraints | Catalog alignment and vehicle compatibility | TBD | TBD |
| ROAD-CAPACITY | Capacity/speed/maintenance only if modeled | Calibrated traffic/fleet scenarios | TBD | TBD |
| TURN-CONNECTIVITY | Legal movements and restrictions per intersection | Turn graph fixtures and route tests | TBD | TBD |
| ROAD-CLOSURES | Blocked state, graph versioning and replanning behavior | Closure/recovery deterministic tests | TBD | TBD |
| ROAD-GRAPH-MIGRATION | Compatibility of road node/edge IDs and saved route references across revisions | Old-save fixtures, graph-diff and deterministic replan tests | TBD | TBD |
| UTILITY-TOPOLOGY | Typed utility nodes/edges, endpoints, direction, elevation constraints, capacity and lifecycle, only for approved V1 networks | Utility-specific topology and flow validation; must not infer road access | TBD | TBD |
| PEDESTRIAN-TOPOLOGY | Pedestrian nodes/edges, legal crossings, permissions and signal/priority state, only if approved | Approved pedestrian scope and crossing/path validation | TBD | TBD |
| BUILDING-FRONTAGE | Road edge to parcel/building frontage relationship | Explicit edge/cell reference validation | TBD | TBD |
| FREIGHT-ENTRY | Regional delivery approach and edge connection | Fleet-compatible route and delivery acceptance | TBD | TBD |
| FREIGHT-ENVELOPE | Vehicle turning/loading/access envelopes | Vehicle class geometry and route constraints | TBD | TBD |

A visual crossing, road stripe, curb, lamp, road mesh or adjacency check does not create graph connectivity. Public transport, bridge, highway and other Deferred/Candidate assets remain governed by the V1 catalog and cannot be promoted here.

### 7.1 Map-to-freight, inventory and economy handoff

The map sheet must show the spatial interfaces needed by the approved starter logistics loop, but this register does not activate any trade, shipment, vehicle or economy feature. Operational IDs and statuses remain governed exclusively by the V1 catalog, item/recipe registry and fleet specification.

| Decision key | Required definition | Required evidence | Current value | Status |
|---|---|---|---|---|
| FREIGHT-ORIGIN-DESTINATION | Exact approved producer, warehouse, workshop and consumer site references; origin/destination access anchors | Catalog/registry reference validation and map overlay | TBD | TBD |
| FREIGHT-ROAD-COMPATIBILITY | Which approved vehicle classes may use each road edge and loading/access point | Fleet-to-edge compatibility matrix and route fixtures | TBD | TBD |
| FREIGHT-LOAD-UNLOAD-ACCESS | Loading/unloading footprint, approach, stopping and destination access constraints | Vehicle envelope, building access and obstruction tests | TBD | TBD |
| FREIGHT-SOURCE-RESERVATION | Source stock reservation and custody transition boundary | Item-ledger conservation and duplicate-dispatch tests | TBD | TBD |
| FREIGHT-DESTINATION-CAPACITY | Destination storage/output capacity reservation and overflow behavior | Full-capacity, partial-delivery and blocked-output tests | TBD | TBD |
| FREIGHT-SHIPMENT-RECOVERY | Route closure, cancellation, process death, return/recovery and cargo-loss policy | Deterministic reroute/recovery and save-resume fixtures | TBD | TBD |
| WAREHOUSE-SITE-CAPACITY | Spatial placement/access of the exact approved warehouse entry and its capacity boundary | Catalog ID/status match, footprint and inventory capacity contract | TBD | TBD |
| RECIPE-RESOURCE-SOURCE | Map deposits, if any, linked only to approved item/recipe producer and extraction rules | Registry ID/unit/recipe graph and bounded-reserve evidence | TBD | TBD |
| ECONOMIC-LEDGER-LINK | Map-linked construction, operating, logistics and maintenance costs connected to approved ledger sources/sinks | Finance reconciliation scenarios; no unowned currency mutation | TBD | TBD |
| WORKFORCE-ACCESS | Valid access relationship between approved workplaces, household cohorts and workforce travel abstraction | Approved workforce model and graph-cost fixtures | TBD | TBD |

These rows must be reconciled against the canonical authorities:
- CAPITAL_REGION_V1_CONTENT_CATALOG.md for building/facility IDs and statuses;
- CAPITAL_REGION_V1_ITEM_RECIPE_REGISTRY.md for item IDs, units, recipes and inventory conservation;
- VEHICLE_FLEET_FREIGHT_TRAFFIC_SPEC.md for vehicle classes, trip/dispatch, route compatibility and freight lifecycle;
- POPULATION_WORKFORCE_MUNICIPAL_ECONOMY.md for cohort employment, household demand and municipal ledger;
- CAPITAL_REGION_MARKET_TRADE_SUPPLY_CHAIN_AND_INTERREGIONAL_COMMERCE_SPEC.md for order, custody, delivery and settlement boundaries.

The starter logistics chain must not be inferred from a freight-terminal concept: LOG-FREIGHT-TERMINAL remains Candidate, VEH-HEAVY-TRUCK remains Candidate, and interregional commerce remains proposal-only. The catalog-approved LOG-WAREHOUSE-STARTER is V1-Required; TRADE-DEPOT is V1-Support. Vehicle class status remains exactly as recorded in the fleet specification; this register does not promote it. ETA is not arrival, dispatch is not delivery, and visual truck placement is not a stock transaction.

## 8. Starter composition and spatial relationships

The spatial specification calls for these functional relationships, but the actual positions and dimensions are not selected here.

| Map component | Required relationship to resolve | Evidence needed | Current decision |
|---|---|---|---|
| Town center | Starter residential plots and approved civic identity | Parcel/access overlay and first-session walkthrough | TBD |
| Local commercial strip | Reachable from homes without unapproved freight assumptions | Road graph and approved service/trade rules | TBD |
| Industrial edge | Freight access and nuisance separation from homes | Fleet envelope and approved impact model | TBD |
| Utility/service reserve | Space for exact catalog-approved facility entries and any future network reservation | Facility footprints and future-proofing rationale | TBD |
| Natural feature | Meaningful constraint/resource only if modeled | Terrain/hydrology/resource contracts | TBD |
| Expansion frontier | Limited locked parcels with clear unlock previews | Parcel state and progression tests | TBD |
| Freight approach | Clear regional delivery access without assuming terminal/cross-region feature | Fleet route and delivery lifecycle | TBD |

No building or facility placement is approved by this table. Exact facilities must match the catalog's stable IDs and statuses.

## 9. Visual map sheet requirements

The eventual approved map sheet must include:
1. Top-down orthographic layout with north/orientation, scale and coordinate grid.
2. Playable boundary, locked expansion, protected land and out-of-bounds regions.
3. Terrain/elevation/slope, hydrology and resource layers as separate togglable overlays.
4. Road graph nodes/edges and road classes, distinct from road mesh art.
5. Parcel boundaries/IDs, footprints, frontage edges and access anchors.
6. Starter composition and freight approach.
7. Legend, revision, data source/provenance, author/reviewer and decision status.
8. Separate visual concept layer; it must never be mistaken for simulation truth.

Concept images generated with plugins may support visual exploration, but editable source data and coordinate-backed layers remain mandatory. Any source asset/layer requires provenance and license records.

## 10. Required validation cases before map approval

- Grid↔world transform round-trip and version migration.
- Every in-bounds cell has complete terrain/buildability metadata.
- No parcel ID duplicates; no unintended parcel overlap or gaps.
- Every footprint resolves to exact cells under each supported rotation.
- Placement is atomic: all footprint cells validate before cost/occupancy mutation.
- Frontage/access anchors reference valid graph edges/nodes.
- Road graph has valid endpoints and no accidental dangling nodes.
- Legal turns and vehicle constraints are consistent with fleet classes.
- Water, slope, protected land and hazard exclusions are deterministic.
- Resource deposits have bounded reserves and a valid approved recipe/extraction owner.
- Expansion does not create inaccessible isolated parcels or invalidate existing saves.
- Freight entry reaches valid destinations under the approved road graph.
- Save/load preserves spatial schema, map revision, parcel/district identity, grid positions and each applicable graph revision.
- Road, utility and (if approved) pedestrian graph revisions migrate independently; stale routes/caches are invalidated deterministically.
- Offline progression follows the approved spatial/network contract; graph changes cannot silently preserve invalid routes or duplicate deliveries/operations.
- Map overlays remain legible on the smallest supported viewport.
- Dense-scene performance is measured on named physical phones; no budget is guessed.

## 11. Approval record

No approval is granted by filling this template. Each decision needs a separate explicit record.

| Field | Required value |
|---|---|
| Map revision | TBD |
| Proposal owner | TBD |
| Spatial review | TBD |
| Simulation/fleet review | TBD |
| UX/visual review | TBD |
| QA evidence links | TBD |
| Project-owner explicit approval | Not granted |
| Approval date | TBD |

## 12. Current non-decisions

The following remain explicitly TBD: map dimensions, grid scale, orientation, natural feature, terrain/elevation/slope data, water clearance, resource types/locations/reserves, parcel count and IDs, starter parcel placement, district boundaries/IDs/ownership, road/access graph and revision, utility graph topology/revision, pedestrian graph scope/topology/revision, road classes/width/capacity/speed/cost, freight entry and road compatibility, freight origin/destination/access anchors, loading/unloading envelopes, source/destination reservations, custody and recovery policy, warehouse site/capacity mapping, resource-to-recipe extraction mapping, workforce access, economic ledger linkage, expansion sequence/cost, utility reserve geometry, spatial schema version, save/offline migration behavior, camera projection, chunk size and device performance budgets.

**No implementation scope is authorized.** This register is complete only as a checklist/template; the Capital Region map itself remains unselected, uncalibrated and unapproved.
