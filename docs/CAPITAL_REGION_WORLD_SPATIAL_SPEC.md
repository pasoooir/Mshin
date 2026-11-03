# MSHIN — Capital Region World, Terrain & Spatial Layout Specification
Version: 0.1.0-design | Status: Draft for review | Scope: Capital Region V1
Target: Cocos Creator 3.8.6, Android/iOS, portrait-first mobile UX

## 1. Design intent
The Capital region must read as a coherent place before it reads as a board. Terrain, water, roads, land value, industry, residential districts and civic services form one legible spatial system. The first map is deliberately bounded so that its complete simulation can be validated on target phones. Exact dimensions and coordinates remain TBD until a playable greybox is profiled.

## 2. Spatial coordinate contract
- Use integer grid coordinates for placement and persistent identity; use world coordinates only for rendering and physics.
- Define one authoritative transform between grid, world and screen coordinates.
- Building footprint, road frontage, interaction hit area and decorative mesh bounds are separate data.
- Rotation is a discrete supported set; rotated footprints are recalculated before placement.
- Terrain elevation and slope are explicit cell attributes, not inferred from texture.
- Save files store grid-space positions and stable definition IDs, never camera-relative positions.
- Grid-to-world scale is versioned. Changing it requires migration and camera/physics regression tests.

## 3. Map layers
| Layer | Authoritative data | Presentation |
|---|---|---|
| Terrain | Cell type, elevation, slope, buildability | Ground mesh, texture, contour |
| Hydrology | Water body, bank, flow class if simulated, flood exclusion | River/lake surface and shoreline |
| Natural resources | Deposit type, reserve, extraction eligibility | Resource nodes and map overlay |
| Roads | Graph nodes/edges, ownership, capacity, blocked state | Road mesh, markings, junction props |
| Zoning/land use | Allowed building families and unlock state | Subtle district tint/overlay |
| Utilities | Network topology and capacity | Optional debug/diagnostic overlay |
| Service access | Route-time and capacity result | Coverage heatmap |
| Ownership/expansion | Unlockable cells/plots and costs | Boundary treatment and expansion preview |

Presentation layers must never become the source of simulation truth.

## 4. Capital map composition
The initial map should contain a readable hierarchy, not a random assortment:
1. **Town center:** starter residential plots, city hall/construction office location, first civic identity.
2. **Local commercial strip:** accessible to homes, limited freight conflict.
3. **Industrial edge:** basic factory/workshop area positioned to reduce noise/pollution exposure to homes.
4. **Utility/service reserve:** space for power, water, sewage and waste facilities with expansion room.
5. **Natural feature:** river, lake, ridge or green corridor that shapes growth and creates meaningful constraints.
6. **Expansion frontier:** a small number of locked parcels that demonstrate future growth without overwhelming first session.
7. **Freight approach:** a clear edge connection for delivery vehicles; no cross-region terminal is assumed in V1.

The exact geography, resource placements and parcel coordinates require a separate approved map layout sheet.

## 5. Terrain and placement semantics
Cell attributes include terrainType, elevationBand, slopeClass, waterAdjacency, naturalResourceTags, buildable, protected and hazardTags. Placement validation returns structured reasons such as OUT_OF_BOUNDS, OCCUPIED, SLOPE_TOO_STEEP, WATER_CLEARANCE, NO_FRONTAGE, WRONG_ZONE, RESOURCE_REQUIRED or LOCKED_PLOT. UI must show a plain-language explanation and a suggested fix.

A footprint can occupy multiple cells. All cells must pass validation before any cost is charged. Placement is atomic. Road frontage is defined by explicit edge/cell references, not visual proximity. Bridges, retaining walls and terrain flattening are deferred unless the core map requires them.

## 6. Road graph and block design
- Road centerlines form a graph with stable node and edge IDs.
- Intersections are explicit graph nodes; visual crossings do not imply connectivity.
- Every road edge defines class, direction rules, nominal speed, capacity, maintenance and construction state.
- Buildings declare one or more access anchors.
- A road closure invalidates routes and triggers bounded replanning.
- Service reach is calculated using route time and provider capacity.
- Freight access and citizen access may use different vehicle constraints.
- Road upgrade must preview changed capacity, cost and affected routes.

## 7. District and land-use logic
District labels are organizational and visual; they do not automatically grant buffs. A district policy can have effects only if represented by explicit rules, costs and acceptance tests. V1 may provide suggested planning areas (residential, commercial, industrial, civic) while allowing player choice subject to nuisance, access and terrain constraints.

## 8. Environmental constraints
Industrial nuisance, noise, waste, water demand and traffic are represented as separate signals. Avoid a single opaque "pollution score" that hides causes. If air/water pollution is not fully simulated in V1, clearly label the model as a simplified impact index and document its sources and sinks. Natural features must not be purely decorative if they are presented as constraints or resources.

## 9. Camera and mobile spatial interaction
- Default camera framing must show a useful neighborhood without making touch targets tiny.
- Pinch zoom, pan and optional rotation must not conflict with placement mode.
- Placement preview follows a stable grid snap and remains legible over varied terrain.
- Selected building anchor and footprint outline remain visible at practical zoom levels.
- Provide a recenter action and a way to return to the active task.
- Build mode, road mode and inspection mode have visibly distinct states.
- Edge scrolling is not required on touch devices.
- Avoid precision gestures as the sole way to place or rotate an asset.
- Respect safe areas and ensure bottom controls do not cover critical map actions.

## 10. Expansion and parcel economy
Expansion is a deliberate progression gate. Each parcel has a stable ID, unlock rule, cost profile, terrain/resource contents and connectivity consequences. Before purchase, preview:
- buildable area gained;
- new natural constraints/resources;
- road extension required;
- additional utility/network cost;
- expected maintenance burden;
- any newly exposed service gap.
No random expansion reward may invalidate an existing save or create unbounded resource generation.

## 11. Performance and streaming
The map is partitioned into spatial chunks for culling and incremental loading. Chunk size is determined by profiling, not guessed. Simulation data remains available independently of visible render chunks. Camera movement must not pause authoritative simulation. LOD transitions must not change collision, footprint or simulation identity. Avoid per-frame allocation in cell traversal and route queries.

## 12. Map validation suite
- Every buildable parcel has valid terrain metadata.
- Every building footprint maps to exact grid cells.
- Road graph contains no accidental dangling node unless explicitly permitted.
- All placed buildings resolve a valid access state.
- Water boundaries and exclusion buffers are consistent.
- Resource deposits have bounded reserves and documented extraction.
- Expansion does not create inaccessible isolated islands.
- Save/load preserves grid positions and map version.
- Camera and touch placement pass on smallest supported viewport.
- Dense city scene meets per-device frame and memory budgets.

## 13. Open decisions
Final map dimensions; grid scale; camera projection and angle; exact natural feature; resource deposits; slope and water-clearance rules; parcel count and expansion sequence; road classes; environmental simulation depth; minimum device profile. These remain open until greybox review and device profiling.


## Visual environment integration
The detailed street hierarchy, neighborhood identity, street furniture, placement envelopes, lighting and mobile visual acceptance rules are maintained in [Capital Region Urban Environment & Street Life Atlas](CAPITAL_REGION_URBAN_ENVIRONMENT_AND_STREET_LIFE_ATLAS.md). Spatial graph and terrain definitions remain authoritative for connectivity and placement; visual appearance must not override them.


## Public transport and road infrastructure visual/design integration

The detailed future-facing hierarchy and design contracts for highways, bridges, intersections, transit corridors, bus stops, terminals, public parking and network expansion are maintained in [Capital Region Public Transport & Road Infrastructure Atlas](CAPITAL_REGION_PUBLIC_TRANSPORT_AND_ROAD_INFRASTRUCTURE_ATLAS.md).

This atlas does not override the spatial graph. Node/edge connectivity, terrain, placement, frontage, grade and route validity remain authoritative here. Bridges and grade-separated roads require explicit terrain/height/clearance support; a visual crossing is never connectivity. Public transport remains Deferred in the V1 catalog.


## Essential utility and municipal service network integration
The conceptual service-network architecture is specified in [Capital Region Essential City Services & Utilities Atlas](CAPITAL_REGION_ESSENTIAL_CITY_SERVICES_AND_UTILITIES_ATLAS.md). Utility graphs are typed graphs distinct from the road/access graph. A pipe/cable crossing or visual line never creates road or utility connectivity. Node/edge endpoints, direction, terrain/elevation constraints, graph versioning, route invalidation and save/load integrity must be explicit. Maintenance and emergency crews use the authoritative road/access graph; underground utility topology does not grant vehicle access. No new network or facility is approved for V1 by this cross-reference.
