# MSHIN — City Spatial Contract Audit

- Status: evidence-based audit; **not an implementation approval**.
- Audit date: 2026-11-03.
- Source code inspected: `pasoooir/Mshin`, branch `fix/city-crossings-require-pedestrian-graph`, commit `6a8196f177829a35fef8d9c8c3d930d436e59626`.
- Design references inspected: `CITY_GAME_DESIGN_MASTER.md` sections 46, 47 and 69; `CAPITAL_REGION_WORLD_SPATIAL_SPEC.md`; `CAPITAL_REGION_URBAN_ENVIRONMENT_AND_STREET_LIFE_ATLAS.md`.
- Purpose: identify spatial-contract mismatches before any ROW, sidewalk, street-furniture, pedestrian or city-simulation implementation.

## 1. Decision and scope boundary

**Do not implement a new sidewalk/ROW, pedestrian graph, road hierarchy, multi-cell footprint, parcel expansion, or new simulation behavior as part of this audit.**

Master design section 46 remains a hard gate: the city-building vertical slice is not approved for new implementation until the design package, V1 content/recipe set, end-to-end production/economy/service loop, traffic/fleet levels, persistence/offline behavior, mobile HUD/build tools, visual bible and real-device acceptance/performance evidence are complete and explicitly approved. The current master document itself says these items remain incomplete and city-building coding has not begun.

This audit is limited to documenting current behavior, identifying mismatches, and defining evidence required before a future design decision. It does not change IDs, save schema, parcel status, simulation values, gameplay rules, or V1 scope.

## 2. Current source-of-truth map

### 2.1 Gameplay grid

Evidence: `src/city/city-view.js`:
- `SIZE=32` and the save key is `mshin-city-save-v2` (line 3).
- `createInitialCity` creates a 32×32 grid and lays down road cells on fixed coordinate bands `[7,8,15,16,23,24]` (line 7).
- The persistent grid stores only tile labels such as grass, road, building, water and zone labels; it does not store terrain elevation/slope, buildability/protected flags, road graph IDs, frontage edges, access anchors, parcel IDs, or a spatial-map version (lines 7, 39).
- `placeCityItem` checks one cell and a four-neighbor road adjacency; it does not validate a graph route, a declared frontage edge, a multi-cell footprint, rotation, terrain, or an atomic footprint reservation (line 28).
- A road can be placed on a grass cell without checking whether it connects to an existing road component. Building access is currently a local adjacency check, not route reachability.

### 2.2 Renderer grid and coordinate transform

Evidence: `src/city/city-three-renderer.js`:
- Renderer builds a 64×64 visual grid (line 3), with a 32×32 active window at visual indices 16–47 (lines 4–8).
- Visual road bands are generated independently using `isRoadCell` (line 7); active gameplay road bands happen to align with the initial 32×32 grid after a +16 visual offset, but the visual renderer is not reading an authoritative road graph.
- Gameplay buildings are rendered at `(item.x - 15.5) * 2` / `(item.y - 15.5) * 2` (line 320), while `tileAt` maps world coordinates back by adding 16 (line 528). This is a renderer-specific transform, not a versioned shared grid/world/screen contract.
- The 64×64 visual expansion is not represented as 64×64 gameplay parcels. Gameplay placement/save state remains 32×32; the outer visual cells are rendered as locked scenery but have no stable parcel identity, unlock state, cost, terrain/resource data, or expansion connectivity consequences.
- Renderer road geometry, curbs and parcel outlines are generated from formulas rather than authoritative road-edge and parcel-boundary records.

### 2.3 Road frontage and service coverage

Evidence:
- `src/city/city-view.js` line 6 defines `roadNear` as orthogonal adjacency to a tile whose value is `road`; building placement uses it at line 28.
- `src/city/city-zoning.js` line 10 duplicates the same adjacency rule; zoning placement uses it at line 13.
- `src/city/city-services.js` line 12 defines Euclidean distance; service coverage uses straight-line radius at line 16.
- No explicit road nodes/edges, turn connectivity, route time, road class, direction, capacity, blocked state, versioned access graph, or building access anchor is present in these inspected city modules.
- The current adjacency/radius checks are prototype rules; they must not be described as road-network reachability or route-based service coverage.

## 3. Compliance matrix

| Requirement | Current evidence | Audit result | Required before future implementation |
|---|---|---|---|
| Integer grid is authoritative; world/screen transform is centralized and versioned | 32×32 gameplay grid and a separate renderer offset/scale | Partial | One shared transform contract and map/scale version; migration and camera/physics regression plan |
| Terrain attributes and buildability are authoritative | Tile labels only; no elevation/slope/protected/buildable metadata | Gap | Approved terrain schema and validation reasons; do not infer from textures |
| Parcel IDs and expansion state are persistent | 32×32 gameplay grid; 64×64 visual locked surround only | Gap | Stable parcel IDs, unlock rules, costs, terrain/resource data and save/load compatibility |
| Road graph has stable nodes/edges and explicit intersections | Road cells and formula-generated markings only | Gap | Versioned graph, stable IDs, edge classes/direction/capacity/state and explicit junction connectivity |
| Building access uses explicit anchors/frontage | Four-neighbor `roadNear` | Gap | Access anchors and explicit frontage/edge references; graph-valid reachability |
| Multi-cell footprints and rotation are validated atomically | One-cell placement; renderer meshes fit visually inside a tile | Gap | Footprint definition, discrete rotation, all-cell validation and atomic cost/reservation |
| Road additions preserve graph connectivity | Road placement accepts any empty grass cell | Gap | Connectivity rules, allowed dangling-end policy and regression scenarios |
| Service access reflects routes and capacity | Euclidean distance/radius in service module | Gap | Route-time and provider-capacity calculation, graph-version invalidation |
| Pedestrian crossing is not advertised without graph/priority | Crosswalk count is zero; smoke test asserts zero | Compliant for this guard | Keep deferred until pedestrian graph, legal crossing nodes and signal/priority exist |
| Street furniture does not occupy buildable parcels | Lamps disabled; readiness false; trees outside the 64×64 visual grid | Partial / guarded | Explicit non-buildable ROW/sidewalk envelopes before any furniture placement |
| Decorative objects do not create hidden gameplay effects | Current perimeter trees are renderer-only; lamps disabled | Compliant for inspected props | Keep decorative-only metadata and tests for collider/service/traffic/land-value/resource effects |
| Street markings match road class, direction and graph | Markings generated by visual index formulas | Gap | Derive markings only from approved road-class/direction data |
| Cocos production asset pipeline and real-device acceptance | Current inspected renderer is a browser Three.js module with procedural meshes | Not demonstrated | Editable source assets/prefabs, provenance/license, mesh/UV/material/LOD QA, Cocos import and real-phone captures/profiling |

## 4. Street-space findings

1. The current curb instances are generated as renderer geometry from adjacent road/grass cells. A curb being visually outside the asphalt does **not** create a legally reserved, non-buildable right-of-way.
2. A parcel cell can still pass the current placement checks while visual curb geometry exists near its edge. The model has no ROW mask to reject placement or reserve sidewalk width.
3. Therefore street furniture remains correctly deferred. Do not restore lamps, benches, planters, hydrants, pedestrian paths, curb ramps or zebra crossings by merely moving their meshes farther from the road centerline.
4. Trees on the outer perimeter are outside the current 64×64 visual parcel grid and are safer than the earlier placement inside locked cells. This is a renderer-boundary safeguard, not a substitute for an authoritative natural-terrain/land-use model.
5. Road markings are currently a visual formula, not a consequence of road class, lane direction or turn connectivity. They must not imply unsupported lanes, legal turns or crossing behavior.

## 5. Acceptance evidence required before a future spatial implementation

The following are design/QA gates, not authorization to code them now:

- A reviewed spatial schema defines map version, grid/world transform version, terrain attributes, buildable/protected masks, stable parcel IDs and expansion state.
- A reviewed road graph defines stable node/edge IDs, intersections, turn connectivity, direction, road class, blockage and graph version.
- Every road/parcel boundary has an explicit ownership/reservation rule; ROW and sidewalk are non-buildable only if the approved schema says so.
- Every building definition supplies footprint cells, supported rotations, access anchors and explicit frontage requirements.
- Placement tests cover bounds, occupancy, terrain, slope, water clearance, zoning, locked parcels, frontage, graph connectivity, rotation and atomic rollback.
- Save/load tests preserve map version, parcel IDs, grid-space positions, graph version and migration behavior.
- Service coverage tests distinguish route-based reachability from straight-line proximity and validate provider capacity.
- Visual QA verifies curb/sidewalk seams, crossing legality, road markings, access envelopes and prop clearance at Far/Mid/Near zoom.
- Every asset has source URL/creator/date/license/provenance, editable source, mesh/UV/material/LOD review and Cocos prefab evidence.
- Mobile acceptance uses actual supported phones; browser emulation is reported separately. FPS, memory, triangles and draw-call budgets remain TBD until measured.

## 6. Explicit non-decisions

This audit does **not** decide:
- final map dimensions or grid scale;
- street widths, road classes, speeds, capacities, costs or intersection spacing;
- sidewalk/ROW width or whether it occupies separate cells or sub-cell geometry;
- parcel expansion sequence, unlock costs or natural-resource placement;
- pedestrian graph, crossing rules or signal policy;
- service catchment formulas, household/traffic counts or economy values;
- final device performance budgets.

All unknown values remain TBD as required by the design documents. No new V1 IDs or status values are introduced.

## 7. Source references

- `docs/CITY_GAME_DESIGN_MASTER.md`: sections 46, 47 and 69.
- `docs/CAPITAL_REGION_WORLD_SPATIAL_SPEC.md`: sections 2, 3, 5, 6, 9, 10, 11 and 12.
- `docs/CAPITAL_REGION_URBAN_ENVIRONMENT_AND_STREET_LIFE_ATLAS.md`: sections 1, 2, 2.2, 2.3, 4, 6, 9 and 10.
- `src/city/city-view.js`: lines 3, 6–7, 28, 39–40.
- `src/city/city-zoning.js`: lines 10, 13, 39.
- `src/city/city-services.js`: lines 12, 16.
- `src/city/city-three-renderer.js`: lines 3–8, 125, 296, 318–320, 522–536.
- `tests/city-view.test.mjs` and `tests/city-zoning.test.mjs`: current coverage is for the prototype grid/adjacency/zoning behavior; it does not establish the missing graph/terrain/parcel contracts.

**Audit conclusion:** preserve the PR #164 safety guards. The next valid step is design reconciliation of the authoritative spatial schema and explicit approval of the section-46 package—not adding more street props or expanding the prototype simulation.
