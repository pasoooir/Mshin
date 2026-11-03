# Capital Region — Essential City Services & Utilities Atlas

**Status:** Conceptual design / future-facing specification. **Not an implementation authorization.**  
**Engine target:** Cocos Creator 3.8.6 / TypeScript. **Primary platform:** Android and iOS, mobile-first.  
**Canonical authority:** `CAPITAL_REGION_V1_CONTENT_CATALOG.md`, spatial authority: `CAPITAL_REGION_WORLD_SPATIAL_SPEC.md`.

## 1. Purpose, scope and authority

This atlas defines a technically coherent design for essential municipal services and utility networks: electricity, potable water, wastewater, solid waste, fire/emergency response, healthcare, policing/public safety, and infrastructure maintenance. It describes systems, dependencies, data contracts, visual communication, mobile interaction, asset production, validation and acceptance evidence.

It is a design reference only. Unless a system and its stable IDs are explicitly approved in the V1 content catalog, every system described here is **proposed / conceptual / not approved for V1**. This document does not activate services, create buildings, change balance, or grant implementation scope. Existing catalog statuses and exclusions remain authoritative.

### 1.1 Non-negotiable rules
- A service is operational only when its authoritative simulation state, network connectivity, capacity, staffing, inventory, budget and lifecycle are defined and tested.
- A building prop, vehicle mesh, pipe decal, power-line mesh, siren, smoke plume or HUD badge is not evidence of a functioning service.
- No service may claim coverage where its route graph, access, capacity or operating schedule cannot support it.
- No UI value may be invented or independently calculated from visual state. Every displayed metric must resolve to a named simulation owner and reconcile with its ledger/state.
- No hidden penalties, arbitrary crime rates, random outages or unmodeled fire spread.
- No guessed numeric capacities, rates, ranges, response times, costs, dimensions, agent caps or device budgets. Unknowns remain **TBD** until measured and approved.
- No production schema is implied by the conceptual entities below.
- Mobile interaction must remain usable one-handed, with readable map overlays, clear touch targets, concise status and accessible color-independent cues.
- Specialist tools and plugins must be used for professional editable 3D production and validation; a generated concept image alone is never a production asset.

## 2. System boundary and service lifecycle

Each proposed service follows the same lifecycle:

1. **Planned:** location and intended service area are shown as a planning preview only.
2. **Under construction:** construction progress and required inputs are explicit; service is not available.
3. **Commissioning:** connectivity, safety constraints, staffing, inventory, power/water and acceptance checks are validated.
4. **Operational:** service output is bounded by effective capacity and current operating conditions.
5. **Degraded:** a measurable fault or shortage reduces output according to an explicit rule.
6. **Unavailable:** no service output is delivered; consumers receive a deterministic unmet-service state.
7. **Maintenance:** work order owns the asset lockout/repair lifecycle; capacity returns only after successful completion and revalidation.
8. **Retired:** asset is disconnected safely; dependent routes and consumers are reconciled.

Transitions must be explicit, auditable and idempotent. A single fault must not be counted twice when a simulation interval is replayed. Construction, operating expense, consumption, repair and replacement must be posted once to the municipal/economic ledger.

## 3. Shared network and dependency architecture

### 3.1 Graph model
Utility networks are typed graphs, not decorative lines:
- **Node:** source, plant, substation, reservoir, pump, junction, valve, manhole, lift station, treatment plant, transfer station, facility connection or other approved endpoint.
- **Edge:** pipe, cable, conduit, sewer segment, service connection or traversable maintenance access segment.
- **Attributes:** stable ID, type, endpoints, directionality, status, capacity (TBD), condition (TBD), ownership, access constraints, construction state, commissioning state, version and provenance.
- **Topology invariants:** endpoints must exist; edge direction and compatibility must be valid; disconnected components must not deliver service; cycles and parallel edges must follow declared rules; deleted/replaced edges invalidate affected routes.
- **Graph versioning:** topology edits increment a version. Consumers cache route results against that version and invalidate deterministically after relevant changes.

Road access is a separate graph. A utility connection is not a road route, and a visible crossing is not a connection. Maintenance crews and emergency vehicles require a valid road/access route; a pipe or cable can cross a road only through a declared crossing/duct/bridge rule.

### 3.2 Dependency graph
Potential dependency relationships include:
- Electricity → pumps, water treatment, wastewater lift/treatment, hospitals, communications and selected municipal facilities.
- Water → households, workplaces, healthcare, fire suppression and industrial processes.
- Wastewater → households, healthcare, workplaces and industrial premises.
- Roads → crew access, waste collection, emergency dispatch, supply delivery and facility access.
- Workforce → plant operations, hospitals, stations, collection fleets and repair crews.
- Inventory → spare parts, treatment chemicals, fuel, protective equipment and repair materials.
- Municipal finance → construction, staffing, energy purchases, maintenance and contracted services.

Dependencies must be directed, typed and bounded. Avoid circular instantaneous calculations: define simulation phase order, previous-tick snapshots or explicit dependency resolution. A downstream service cannot silently create upstream supply.

### 3.3 Simulation phase contract
Proposed deterministic phase order (exact tick duration TBD):
1. Apply player-authorized topology/building changes.
2. Validate graph topology and connectivity.
3. Apply scheduled demand and production inputs.
4. Resolve source availability and network throughput.
5. Resolve facility operating constraints (power, water, staff, inventory).
6. Allocate service to consumers using declared priority/fairness policy.
7. Resolve incidents, faults and service degradation.
8. Create/advance work orders and repair effects.
9. Post costs, consumption and service outcomes to ledgers.
10. Publish immutable presentation snapshots and audit events.

The exact ordering of incident creation versus service allocation must be selected and tested; it must never vary nondeterministically between devices.

## 4. Electricity network (proposed conceptual system)

### 4.1 Scope
Conceptual layers: generation or external supply interface, high-level intake, substations, distribution feeders, transformers, overhead/underground distribution, service drops and consumer connections. Generation is not assumed to exist in V1; if the catalog does not approve it, represent supply only as a clearly labeled external-source abstraction in design diagrams.

### 4.2 Network and operating rules
- Supply nodes expose available output and operating state.
- Substations/transformers convert or distribute supply through explicit compatible connections.
- Feeders and cables have directional topology and capacity constraints.
- Consumers declare demand classes and priority only when approved by the simulation design.
- Delivered energy must never exceed source availability, edge capacity or facility throughput.
- Allocation policy must define priority, proportional sharing, rotating fairness or another deterministic method; no implicit “nearest building always wins”.
- Losses, voltage simulation, phase balancing and detailed electrical engineering are optional future complexity and must not be fabricated in a simplified model.
- Outages must be attributable to a fault, maintenance lockout, insufficient supply or approved event. Each outage has affected graph component, start time, cause, severity and restoration state.
- Load shedding, reserve margins and backup generation remain unimplemented until explicit rules and balance data are approved.

### 4.3 Failure and restoration
Fault classes may include source unavailable, feeder disconnected, transformer unavailable, damaged segment and planned maintenance. Each class needs detection rule, affected consumers, service impact, repair requirement and acceptance test. A visual spark or darkened window is presentation only unless backed by the fault state.

### 4.4 Physical asset families
Substation compounds, transformer kiosks, poles, insulators, crossarms, cable bundles, underground cabinets, manholes, utility trenches, warning markers, service meters and maintenance vehicles. Every asset requires scale reference, modular connection points, collision/access policy, LODs and a clear visual distinction between energized, isolated, damaged and under-construction states.

## 5. Potable water network (proposed conceptual system)

### 5.1 Supply and treatment chain
Potential chain: source/intake → raw-water conveyance → treatment → treated-water storage/reservoir → pumping/pressure zones → distribution mains → local branches → consumer connection. Do not assume a specific source type or treatment process until the world/catalog design approves it.

### 5.2 Hydraulic abstraction
A simplified city simulation may model flow and capacity without full fluid dynamics. It must still define:
- source availability and treatment output;
- storage inventory and refill/drain rules;
- pump availability and power dependency;
- edge throughput and direction;
- pressure-zone compatibility or an explicitly simpler reachability abstraction;
- demand per consumer class;
- allocation and shortage policy;
- leakage/fault effects only if they have explicit state and cost.

A connected pipe alone does not guarantee delivered water. A consumer is served only if a valid source-to-consumer path exists and all active constraints permit delivery. Do not imply pressure, water quality or potable safety beyond the modeled abstraction.

### 5.3 Water quality and safety
Treatment quality may be represented as discrete validated states (for example, compliant / treatment degraded / unavailable) only if the model defines how states are produced and consumed. Do not invent contamination events, health impacts or chemical parameters. Any water-quality incident must identify affected network components and consumers, isolation actions, flushing/repair workflow and reopening acceptance.

### 5.4 Fire-water dependency
Fire response may depend on declared hydrant/water access only if hydrants and water supply are modeled. A hydrant prop does not provide suppression. If no fire-water simulation exists, clearly label hydrants as decorative and do not imply operational benefit.

## 6. Wastewater and sewerage (proposed conceptual system)

### 6.1 Collection and treatment chain
Potential chain: premises connection → local sewer → trunk sewer → gravity junction or lift station → treatment plant → approved discharge/reuse endpoint. Terrain elevation, grade, direction, invert levels and pump dependencies matter. Do not treat sewer edges as generic undirected roads.

### 6.2 Constraints and faults
- Flow generation derives from served premises only under a declared demand conversion rule.
- Segment and facility capacity are explicit; overload behavior must be deterministic.
- Lift stations depend on electricity and maintenance.
- Treatment throughput cannot exceed operating capacity or required inputs.
- Blockage, pump failure, overflow and treatment outage are separate fault types, each with affected component and service consequence.
- Environmental pollution, disease or property damage must not be simulated unless explicitly designed, balanced and reviewed; no invisible penalty may be attached to a red map overlay.

### 6.3 Visual states
Show underground networks through an optional mobile diagnostic overlay rather than cluttering the default city view. Surface indicators should be localized to an actual incident: work barriers, crew, warning marker or visible repair only where the simulation state supports it.

## 7. Solid waste, collection and recycling (proposed conceptual system)

### 7.1 Material flow
Potential chain: premises waste generation → bin/container → collection stop → collection vehicle → transfer/sorting facility → recycling, treatment or disposal destination. The material categories and conversion rates remain TBD; avoid inventing detailed waste chemistry.

### 7.2 Collection operations
- Collection demand is generated from modeled premises/population or workplaces through explicit rules.
- Bins have finite capacity only if capacity is actually modeled.
- Routes must use compatible road edges, vehicle restrictions and accessible collection points.
- Trips record assigned vehicle, route version, stops, collected amount, destination and completion state.
- Missed collection must have a cause (vehicle unavailable, route blocked, facility closed, schedule not due, or capacity limit).
- Collection must be idempotent: replaying a tick cannot duplicate pickup, disposal, recycling credit or expense.

### 7.3 Facilities and economy
Transfer, sorting, recycling and disposal facilities require staffing, access, operating inputs, throughput and costs. Recycling output must be a traceable material flow, not a decorative green percentage. Landfill capacity, pollution and long-term effects are outside scope until explicitly approved.

## 8. Fire and emergency response (proposed conceptual system)

### 8.1 Incident lifecycle
Proposed incident state: reported → validated → queued → dispatched → en route → on scene → response active → contained/resolved → returned to service → closed. False alarms, duplicate reports, cancellation and escalation need explicit transitions.

### 8.2 Dispatch and coverage
- Station coverage is based on valid road routing and dispatchable vehicles/crew, not a circular radius alone.
- A unit is dispatchable only when staffed, available, equipped and connected to a valid route.
- Dispatch selection must define deterministic priority and tie-breaking.
- Blocked roads, vehicle size restrictions and unavailable bridges/ramps affect route feasibility.
- Arrival time is not to be shown until travel-time model and evidence exist; otherwise show qualitative reachability.
- Fire spread, building damage, casualties and suppression mechanics remain out of scope unless separately approved and technically specified.

### 8.3 Water and supplies
Response capability may require water, equipment, fuel and crew. Only dependencies actually modeled may influence outcome. Do not award suppression benefit for a nearby hydrant unless a valid water path and usable flow are established.

### 8.4 Visual presentation
Emergency lights, sirens, smoke, flames, hose deployment and crew animations must be driven by incident/unit state. No siren loop or fire effect may persist after the owning state closes. Mobile users need a clear incident marker, severity label if defined, unit status and a tap-to-inspect panel.

## 9. Healthcare services (proposed conceptual system)

### 9.1 Facility and capacity
Potential facility tiers include clinic, urgent-care facility and hospital, but tiers are not approved content IDs. A healthcare facility can provide service only when its staffing, operating state, access, capacity and required supplies are valid.

Possible capacity dimensions (all TBD): service slots, beds, staffed capacity, emergency intake, supplies and operating hours. Do not collapse these into one invented “health” score.

### 9.2 Demand and access
Demand should derive from explicit population cohorts or incident referrals, not arbitrary random patient counts. Reachability uses the road graph and access restrictions. If travel-time and patient simulation are not implemented, show only qualitative service access and clearly label it.

### 9.3 Privacy and presentation
Avoid personal medical records or granular patient identity. Aggregate operational indicators only. Do not expose sensitive simulated patient details in public city UI. Staff, ambulances, supply deliveries and facility activity must be driven by actual operational state.

## 10. Police and public safety (proposed conceptual system)

### 10.1 Scope and safeguards
Potential abstractions include station, patrol unit, dispatch, incident response and emergency coordination. These are not approved V1 IDs. Do not invent crime rates, demographic correlations, surveillance mechanics, citizen profiling or punitive outcomes. No sensitive real-world group should be used as a proxy for risk.

### 10.2 Operational model
If approved, incidents must have explicit non-demographic causes, lifecycle, location precision, report/validation state and resolution. Patrol coverage must use valid road routes and staffed available units, not decorative patrol cars or arbitrary radius. Response priority, escalation, staffing and operating costs require documented rules.

### 10.3 UI and privacy
Show aggregate service availability and incident workflow. Avoid individual resident tracking, identifiable dossiers, face recognition, personal surveillance and stigmatizing heatmaps. A “security” overlay must communicate modeled service reach, not imply unsupported crime prediction.

## 11. Infrastructure maintenance and municipal works (proposed conceptual system)

### 11.1 Asset registry
Each maintainable asset needs stable identity, asset class, placement, owner/operator, construction/commissioning state, condition model (if approved), service dependencies, last inspection, work-order link and provenance. If condition is not modeled, do not display a fake durability percentage.

### 11.2 Work-order lifecycle
Proposed states: detected/reported → triaged → approved/scheduled → crew assigned → materials reserved → access secured → work in progress → verification → restored/closed. Cancellation, failed repair, rework and emergency priority must be explicit.

### 11.3 Repair constraints
A repair can proceed only when crew skills, vehicle, road access, safety isolation, spare parts, tools and work window satisfy requirements. Material reservation and consumption must be transactional and idempotent. A repaired asset returns to service only after a defined validation step; a visual animation alone cannot close a work order.

### 11.4 Preventive maintenance
Preventive schedules are future scope until asset condition, wear drivers and time semantics are approved. Do not invent decay rates or random breakdown probability. Emergency repairs and planned maintenance must be distinguishable in budgets and service dashboards.

## 12. Cross-system operational contracts

| Consumer / facility | Required upstream contract | Failure behavior |
|---|---|---|
| Residential premises | Approved electricity/water/wastewater/waste rules | Explicit unmet service; no hidden penalty |
| Industrial workplace | Declared utilities, access, staff and inputs | Output changes only through declared production rules |
| Water pumping/treatment | Power, source, operating capacity, staff | Throughput limited or unavailable |
| Wastewater lift/treatment | Power, incoming flow, capacity, staff | Explicit backlog/degraded/unavailable state |
| Hospital/clinic | Road access, staff, supplies and approved utilities | Reduced/unavailable service only under defined rule |
| Fire station/unit | Staff, vehicle, road access, equipment | Unit not dispatchable |
| Waste collection | Road graph, vehicle, crew, destination capacity | Stop/trip remains incomplete with a cause |
| Maintenance crew | Road access, skills, vehicle, parts and safe isolation | Work order blocked with actionable reason |

Contracts must specify ownership, read/write boundaries, units, tick timing, stale-data policy, failure semantics and telemetry. Presentation reads snapshots; it never mutates transactions or authoritative simulation state.

## 13. Data model concepts (not a production schema)

Suggested conceptual records:
- `UtilityNetwork`: network ID/type, graph version, owner, status.
- `UtilityNode` / `UtilityEdge`: stable IDs, endpoints, type, constraints, state and provenance.
- `ServiceFacility`: facility type, network links, staff, inventory, operating state and capacity.
- `ConsumerConnection`: premises/facility ID, service type, demand rule and connection state.
- `ServiceAllocation`: tick, source, consumer, requested, delivered, unmet and reason.
- `Incident`: type, location, cause, severity (only if defined), lifecycle and affected assets.
- `ResponseUnit`: station, vehicle, crew, equipment, availability and current assignment.
- `WasteTrip`: route version, vehicle, stops, collected material, destination and completion.
- `MaintenanceAsset` / `WorkOrder`: asset identity, fault, priority, crew, reserved materials, lifecycle and verification.
- `ServiceSnapshot`: immutable presentation state with source tick/version.
- `AuditEvent`: actor/system, action, target, previous/new state references, tick and correlation ID.

All IDs, schemas, persistence formats and migrations require approval. Enforce referential integrity, version checks, ownership boundaries, deterministic ordering and idempotency keys. Save/load must preserve graph versions, active incidents, assignments, reservations and in-progress work without duplication.

## 14. Mobile-first city presentation and interaction

### 14.1 Map layers
Provide separate, user-toggleable diagnostic overlays for electricity, water, wastewater, waste routes, emergency reachability, healthcare access and maintenance. Each overlay needs:
- a clear legend with text/icon/pattern, not color alone;
- an explicit “data as of tick” indicator;
- selected network/facility details;
- disconnected, overloaded, degraded, planned and unknown states;
- a way to return to the normal city view without losing selection.

Never show every utility layer simultaneously by default. Prioritize legibility on small screens and avoid dense lines over buildings.

### 14.2 Inspection panel
A selected asset panel should show: name/type, operational state, connected upstream/downstream nodes, service consumers, active incident/work order, actual capacity/demand only if modeled, current constraints, last state change and actionable next step. Unknown fields display “Not modeled” or “TBD”, not fabricated numbers.

### 14.3 Touch and accessibility
Use large touch targets, safe-area-aware layouts, one-handed navigation, clear focus/selection, zoom-independent labels where practical, screen-reader labels, sufficient contrast and redundant icon/text/pattern encoding. Critical alerts must not rely on red/green alone. Confirm destructive network edits and clearly distinguish planning preview from committed construction.

## 15. Professional 3D art and specialist tool pipeline

### 15.1 Required asset families
- Electricity: substations, transformers, poles, cable hardware, cabinets, trench modules and utility crew.
- Water: intake/treatment modules, reservoirs, pump houses, tanks, valves, hydrants, pipes and repair crew.
- Wastewater: manholes, sewer access, lift stations, treatment modules, outfall structures and maintenance vehicles.
- Waste: bins, collection containers, compactor trucks, transfer/sorting modules, recycling equipment and depot props.
- Emergency: fire station, response vehicles, apparatus, hose/equipment and crew.
- Healthcare: clinic/hospital exterior modules, ambulance, loading/service access and equipment silhouettes.
- Public safety: station exterior, patrol vehicle and dispatch/maintenance props, without surveillance imagery.
- Maintenance: depots, work-zone barriers, excavations, service trucks, tools, replacement modules and safety equipment.

### 15.2 Production requirements
Each production asset must include editable source project, clean topology, UVs, PBR material definitions, texture packing, pivot/origin convention, scale reference, collision policy, LOD chain, mobile shader compatibility, prefab hierarchy, animation/state hooks, dependency manifest and automated validation. Road/utility snap points must be explicit and machine-checkable.

### 15.3 Specialist tools and plugins
Use Blender for editable mesh, UV, material, rig and LOD work; use appropriate procedural modeling/geometry-node workflows for repeatable network modules; use texture tools with documented export settings; use Cocos Creator import/prefab/material validation and device profiling. Use specialist plugins where they materially improve geometry generation, retopology, UV packing, PBR authoring, rigging, batch export, prefab assembly or validation. Tool choice must be recorded per asset family and output must remain editable—not flattened screenshots.

### 15.4 Free asset governance
Zero-budget or minimum-cost policy: use only assets with clearly documented commercial-use rights compatible with distribution. Record source URL, creator, exact license/version, attribution obligations, modifications, retrieval date, file hash and review status. “Free download” is not proof of commercial permission. Reject unclear, non-commercial-only, untraceable or incompatible assets. Maintain original files and license evidence; do not mix incompatible licenses into a distributable bundle.

## 16. Cocos Creator integration boundaries

- Simulation/domain state remains in TypeScript services independent of scene nodes.
- Scene components subscribe to immutable snapshots and map authoritative states to visuals.
- Prefabs must not own economic or network truth.
- Network topology and simulation tests run headlessly where possible.
- Visual effects are spawned/stopped through state-driven presentation controllers with cleanup on disable, scene unload and save/load.
- Object pooling and LOD are applied only after profiling on target phones.
- Mobile performance targets, memory ceilings, draw-call budgets, texture limits, thermal behavior and minimum supported devices remain TBD until a reproducible device matrix is selected and measured.
- Avoid unbounded per-building/per-edge Update loops; use scheduled simulation phases, spatial partitioning and batched presentation updates after profiling.

## 17. Validation and acceptance matrix

| Area | Required acceptance evidence |
|---|---|
| Graph integrity | Automated tests reject dangling nodes, incompatible edges and invalid directions |
| Connectivity | Disconnected component delivers zero service |
| Capacity | Delivered output never exceeds source, edge or facility constraints |
| Allocation | Deterministic tie-breaking and documented fairness/priority |
| Outage | Fault affects only reachable dependent components under declared rules |
| Restoration | Service returns only after repair and revalidation |
| Power dependency | Pump/treatment dependency resolves in documented phase order |
| Water | Source-to-consumer path and treatment state are enforced |
| Wastewater | Flow, lift station and treatment capacity are bounded |
| Waste collection | Route restrictions, pickup idempotency and destination capacity are tested |
| Emergency | Dispatch requires staffed unit and valid route; lifecycle closes cleanly |
| Healthcare | Service access/capacity derives only from approved modeled inputs |
| Public safety | No demographic profiling, unsupported crime prediction or personal tracking |
| Maintenance | Crew, access, parts, isolation and verification gates are enforced |
| Economy | All operating/repair costs reconcile with municipal ledger |
| Persistence | Save/load preserves graph, incidents, assignments and reservations without duplication |
| UI truth | Every metric traces to a state owner and source tick |
| Mobile UX | Touch, readability, safe areas, accessibility and orientation tested on phones |
| Visual quality | Prefab, material, UV, LOD, animation and mobile rendering review evidence |
| Asset rights | Per-file license/provenance/hash audit passes |
| Performance | Real-device profiler evidence for frame time, memory and thermal behavior |

### 17.1 Required scenario tests
1. Disconnect one feeder: only dependent consumers lose electricity; unrelated network components remain unchanged.
2. Disable a pump: downstream water delivery follows the documented dependency and phase order.
3. Isolate a contaminated/quality-degraded segment: affected consumers are traceable; no unmodeled health effect appears.
4. Block a sewer segment: upstream backlog/overflow occurs only if such behavior is explicitly modeled.
5. Close a waste facility: collection trips cannot silently complete or dispose of material.
6. Block a road: waste, emergency and maintenance routes recalculate against the new graph version.
7. Remove a response unit's crew: it becomes undispatchable.
8. Close a hospital facility: access and capacity indicators update from authoritative state.
9. Reserve the last repair part twice: only one reservation succeeds.
10. Replay the same tick: no duplicate pickup, expense, repair consumption, incident transition or service allocation.
11. Save during active maintenance, reload and finish: no duplicated crew/material or premature restoration.
12. Change a network edge: dependent route caches invalidate; no stale route is used.
13. Disable a visual effect/controller: simulation state remains unchanged.
14. Inspect on a small phone: overlays, legends and panels remain legible and touchable.

## 18. Open decisions and explicit TBD register

- Which, if any, utility/service systems belong in V1 versus later releases.
- Whether electricity is an external supply abstraction or includes generation.
- Exact service classes, demand units, allocation policy and simulation tick.
- Network scale, topology granularity, terrain/elevation representation and underground visibility.
- Water source, treatment abstraction, pressure model and quality scope.
- Wastewater flow and environmental consequence scope.
- Waste material categories, collection cadence, facility types and destination rules.
- Emergency incident types, dispatch policy and whether fire spread is ever modeled.
- Healthcare service tiers, capacity dimensions and patient abstraction.
- Public-safety incident scope and privacy boundaries.
- Asset condition/wear model and preventive maintenance policy.
- Numeric capacity, costs, rates, storage, response times, crew sizes and vehicle specifications.
- Mobile device floor, LOD count, memory/texture/draw-call/frame-time budgets.
- Final asset list, tool/plugin versions and file-level licenses.

No value is to be guessed to make a table appear complete. Record a decision owner, rationale, test method and approval evidence when each TBD is resolved.

## 19. V1 catalog protection and implementation gate

This atlas does not add operational IDs, change content status, or authorize V1 implementation. The existing catalog remains the single source of truth. Any proposed service entering V1 must first receive:
1. approved stable IDs and explicit status in the catalog;
2. a scope boundary and dependency map;
3. data contracts, lifecycle and deterministic simulation rules;
4. economy, staffing, inventory and save/load behavior;
5. mobile UI and professional asset briefs;
6. license/provenance plan;
7. automated acceptance tests and real-device QA plan;
8. explicit approval to leave the design phase.

## 20. Current evidence status

- This document is a design specification only.
- No utility network, facility, emergency unit, service simulation or maintenance workflow has been implemented by this change.
- No 3D asset has been downloaded, licensed, imported, hashed or accepted by this change.
- No mobile device test, performance profile or gameplay acceptance run is claimed.
- All canonical catalog statuses remain unchanged.


## Education, population growth and service-capacity balancing
The education/housing/wellbeing model is defined in [Capital Region Education, Research, Housing Growth & City Wellbeing Atlas](CAPITAL_REGION_EDUCATION_RESEARCH_HOUSING_AND_CITY_WELLBEING_ATLAS.md). Utility and municipal service demand must respond to population changes only through approved demand-conversion rules. New homes increase potential residential capacity, not immediate population; new schools or service facilities increase nominal capacity only, and effective delivery remains constrained by staff, utilities, access, operating state and budget. A population increase may raise utility/service demand; a service shortfall may affect migration or wellbeing only if an explicit approved causal rule exists. No decorative facility, assumed coverage or unmodeled score penalty is permitted.


## District allocation and crisis operations integration
The district allocation and crisis model is specified in [Capital Region District Resource Allocation & Crisis Management](CAPITAL_REGION_DISTRICT_RESOURCE_ALLOCATION_AND_CRISIS_MANAGEMENT_SPEC.md). Service requests, utility work, emergency response and maintenance must use a shared auditable resource lifecycle while retaining domain-specific units and safety rules. A resource reservation is exclusive; dispatch is not delivery; restoration requires service acceptance evidence. Typed utility graphs and the authoritative road/access graph remain distinct. No additional service, incident or dispatch capability is approved by this cross-reference.


## Municipal finance and funded-service integration

Operating and capital funding rules are specified in [Capital Region Municipal Finance, Taxation, Budgeting & Governance](CAPITAL_REGION_MUNICIPAL_FINANCE_TAXATION_BUDGETING_AND_GOVERNANCE_SPEC.md). Utility and public-service operations must account for funded OPEX, staffing, energy, supplies, maintenance, procurement and asset lifecycle obligations. Budget authority, available cash, commitment, accepted input delivery and actual service output remain separate states. A facility cannot be treated as sustainably operational merely because construction is complete; commissioning, staffing, network dependencies and operating funding must be valid. This cross-reference creates no new V1 service IDs or operating guarantees.


## Tourism load on essential services

The tourism model is specified in [Capital Region Tourism, Visitors, Attractions & Hospitality](CAPITAL_REGION_TOURISM_VISITORS_ATTRACTIONS_AND_HOSPITALITY_SYSTEM_SPEC.md). Incremental visitor load may affect water, electricity, waste, healthcare, safety, emergency response and maintenance only through explicit authoritative demand rules. Visitor and resident demand must remain separately attributable; staffing, effective capacity and delivered service are distinct. This cross-reference does not activate any new service or guarantee visitor-priority allocation.
