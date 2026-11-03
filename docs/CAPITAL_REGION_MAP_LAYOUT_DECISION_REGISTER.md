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
| PARCEL-IDS | Stable parcel IDs and map-version relationship | Parcel table and duplicate/overlap checks | TBD | TBD |
| PARCEL-FOOTPRINTS | Exact cell sets, shape and rotation support | Footprint fixtures and atomic placement tests | TBD | TBD |
| BUILDABILITY | Per-cell buildable/protected/occupied/unlocked state | Terrain and parcel validation matrix | TBD | TBD |
| FRONTAGE | Explicit frontage edges and compatible road references | Graph/parcel topology checks | TBD | TBD |
| ACCESS-ANCHORS | Building access anchors and allowed vehicle/pedestrian modes | Building-family access contracts | TBD | TBD |
| EXPANSION-ORDER | Locked parcel sequence and prerequisites | Progression and save migration scenarios | TBD | TBD |
| EXPANSION-COST | Cost/resource/maintenance profile | Approved economy model and affordability tests | TBD | TBD |

District labels alone must not create buffs. Expansion must preview buildable area, natural constraints/resources, required road extension, network cost, maintenance and service gaps. No parcel count or cost is assumed here.

## 7. Road/access graph and freight approach

The road/access graph is separate from its rendered road mesh. The graph is also distinct from utility networks and any pedestrian graph.

| Decision key | Required definition | Required evidence | Current value | Status |
|---|---|---|---|---|
| ROAD-NODES | Stable node IDs, coordinates, intersection semantics | Graph export and topology validation | TBD | TBD |
| ROAD-EDGES | Stable edge IDs, endpoints, direction and lifecycle | Graph export, connectivity and dangling-node tests | TBD | TBD |
| ROAD-CLASSES | Exact approved V1 road classes and constraints | Catalog alignment and vehicle compatibility | TBD | TBD |
| ROAD-CAPACITY | Capacity/speed/maintenance only if modeled | Calibrated traffic/fleet scenarios | TBD | TBD |
| TURN-CONNECTIVITY | Legal movements and restrictions per intersection | Turn graph fixtures and route tests | TBD | TBD |
| ROAD-CLOSURES | Blocked state, graph versioning and replanning behavior | Closure/recovery deterministic tests | TBD | TBD |
| BUILDING-FRONTAGE | Road edge to parcel/building frontage relationship | Explicit edge/cell reference validation | TBD | TBD |
| FREIGHT-ENTRY | Regional delivery approach and edge connection | Fleet-compatible route and delivery acceptance | TBD | TBD |
| FREIGHT-ENVELOPE | Vehicle turning/loading/access envelopes | Vehicle class geometry and route constraints | TBD | TBD |

A visual crossing, road stripe, curb, lamp, road mesh or adjacency check does not create graph connectivity. Public transport, bridge, highway and other Deferred/Candidate assets remain governed by the V1 catalog and cannot be promoted here.

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
- Save/load preserves map revision, parcel identity and grid positions.
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

The following remain explicitly TBD: map dimensions, grid scale, orientation, natural feature, terrain/elevation/slope data, water clearance, resource types/locations/reserves, parcel count and IDs, starter parcel placement, district boundaries, road graph, road classes/width/capacity/speed/cost, freight entry, expansion sequence/cost, utility reserve geometry, camera projection, chunk size and device performance budgets.

**No implementation scope is authorized.** This register is complete only as a checklist/template; the Capital Region map itself remains unselected, uncalibrated and unapproved.
