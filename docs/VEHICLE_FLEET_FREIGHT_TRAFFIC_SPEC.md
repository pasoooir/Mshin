# MSHIN — Vehicle Fleet, Freight, Traffic & City Logistics Specification
Version: 0.1.0-design | Status: Draft | Scope: Capital V1 foundations

## 1. Design objective
Vehicles must be functional simulation actors, not moving decorations. At the same time, a mobile city builder cannot afford full individual-agent simulation for every citizen and freight trip. This design uses layered fidelity: authoritative trip/job records, sampled visible agents and aggregated background flows.

## 2. Vehicle classes
| Class ID | Role | V1 status | Core constraints |
|---|---|---|---|
| VEH-CITIZEN-CAR | Household/private trip | Candidate | Road class, congestion, parking if modeled |
| VEH-DELIVERY-VAN | Workshop/factory delivery | V1-Support | Payload, route, pickup/drop-off |
| VEH-HEAVY-TRUCK | Bulk freight | Candidate | Road restrictions, turning, payload |
| VEH-FIRE-ENGINE | Fire response | V1-Support | Emergency routing, dispatch availability |
| VEH-POLICE-CAR | Police response | V1-Support | Dispatch and coverage |
| VEH-AMBULANCE | Health response | V1-Support | Dispatch and service capacity |
| VEH-WASTE-TRUCK | Waste collection | V1-Support | Collection route, load capacity |
| VEH-CONSTRUCTION-TRUCK | Project delivery | Candidate | Material shipment and site access |
| VEH-BUS | Public transport | Deferred | Stops, routes, passenger capacity |
| VEH-DECORATIVE | Visual ambience only | Decoration | No economic/service effect |

## 3. Vehicle definition contract
Every operational vehicle declares stable ID, vehicle class, visual asset/prefab, dimensions, collision envelope, road compatibility, speed profile, acceleration/braking model, turn radius, capacity, energy/fuel/upkeep profile if used, job state machine, route policy, LOD profile, animation/sound profile, save policy and acceptance suite.

Vehicle art scale and collision dimensions are independent. A decorative vehicle must not carry passengers, cargo, emergency capacity or traffic effects.

## 4. Trip and dispatch model
A trip is an authoritative record: tripId, origin, destination, cargo/passenger amount, priority, assigned vehicle class, route version, created time, departure time, ETA, state, completion result and idempotency key. States: requested, queued, assigned, en-route, loading, unloading, completed, failed, cancelled and rerouting.

Dispatch must validate:
- origin/destination exist and are reachable;
- vehicle capacity and compatibility;
- route permits vehicle class;
- pickup inventory/passenger reservation exists;
- delivery destination can accept payload;
- route closure and timeout behavior.

A completed trip updates cargo/stock exactly once. UI animation cannot itself complete a transaction.

## 5. Traffic fidelity tiers
- **Tier A — Aggregate:** background trips represented as edge flow counts and average travel cost. Used for distant/low-priority simulation.
- **Tier B — Sampled agents:** selected trips spawn visible vehicles; aggregate counts remain authoritative.
- **Tier C — Focused simulation:** nearby/selected intersections and emergency incidents receive more detailed movement and conflict handling.

Switching tiers must preserve trip progress and outcomes. Rendering visibility must not determine whether a trip exists or completes.

## 6. Road capacity and congestion
Each edge declares nominal capacity and speed profile. Congestion is computed from demand/flow with a bounded function and documented hysteresis to avoid rapid oscillation. Route cost may combine travel time, turn penalty, restrictions and reliability. Do not use arbitrary congestion penalties without calibration.

Pathfinding requirements:
- deterministic route tie-breaking;
- route cache invalidation by graph version;
- bounded replanning frequency;
- fallback for unreachable destinations;
- no per-frame full graph search;
- route results independent of visual agent spawn.

## 7. Freight chain
A freight job links producer stock to a destination reservation. Sequence:
1. Create shipment request.
2. Reserve source inventory.
3. Validate destination capacity.
4. Assign compatible vehicle and route.
5. Load payload.
6. Advance trip according to simulation clock.
7. Unload atomically and release reservations.
8. Write ledger/telemetry.
9. Recover safely from cancellation, route closure or process death.

In-transit stock remains owned and visible. Failed shipment policy specifies whether cargo returns, remains at source, or enters a recoverable lost/damaged state; no silent disappearance.

## 8. Emergency response
Incidents create demand records with severity, location and response deadline/fairness window. Dispatch chooses available compatible units by route time and capacity. If no unit is available, the UI explains why. Incident consequences must be proportionate, warned and recoverable; no unavoidable catastrophic loss due to hidden simulation.

## 9. Mobile performance controls
- Cap visible agents per camera region and device profile.
- Use pooled entities; avoid frequent instantiate/destroy churn.
- Distant traffic uses instanced/aggregated rendering where supported.
- Physics is limited to nearby interactions; path/traffic logic is not delegated to per-frame rigidbody simulation.
- LOD and animation update rates scale by distance and importance.
- Simulation tick rate is independent of render FPS.
- Pause/resume and backgrounding cannot duplicate trip progress.

## 10. Acceptance tests
- Delivery reserves source stock and destination capacity.
- Full destination blocks dispatch or unloading safely.
- Duplicate completion cannot duplicate cargo.
- Road closure triggers deterministic reroute or visible failure.
- Vehicle restrictions are honored.
- Emergency unit cannot serve two simultaneous trips beyond capacity.
- Decorative vehicle changes no simulation metric.
- Tier switching preserves trip ETA/outcome.
- Save/load resumes active trip once.
- Offline catch-up produces same result as equivalent online simulation interval.
- Dense traffic remains within target device frame/memory budgets.


## Street-scene visual integration
Vehicle presentation, parking props, visible traffic flows, pedestrians and emergency access must follow [Capital Region Urban Environment & Street Life Atlas](CAPITAL_REGION_URBAN_ENVIRONMENT_AND_STREET_LIFE_ATLAS.md). The fleet/traffic simulation remains the source of truth for moving vehicles and trips; decorative parked vehicles must never block graph routes or imply active trips.


## Vehicle and mobility visual production integration

The detailed class-by-class art, state, animation, road-use, parking, pedestrian-boundary, specialist-tool, provenance and mobile acceptance requirements are defined in [Capital Region Vehicle & Mobility Visual Atlas](CAPITAL_REGION_VEHICLE_AND_MOBILITY_VISUAL_ATLAS.md).

The fleet specification remains authoritative for trip, dispatch, freight, capacity, route and simulation outcomes. The visual atlas cannot add operational vehicle classes or activate Candidate/Deferred content. Presentation consumes authoritative state and cannot write to trip or inventory transactions. All unknown dimensions, rates, agent caps and device budgets remain TBD until measured.

## Public transport and road infrastructure integration

The future transit network, bus stop/terminal/depot, passenger demand, boarding/capacity, transit priority, parking and road hierarchy design are specified in [Capital Region Public Transport & Road Infrastructure Atlas](CAPITAL_REGION_PUBLIC_TRANSPORT_AND_ROAD_INFRASTRUCTURE_ATLAS.md).

This fleet specification remains authoritative for vehicle/trip/dispatch behavior. `VEH-BUS` and public transport remain Deferred; no passenger trip, bus service or transit benefit is activated by the visual/design atlas. A bus line must eventually resolve to compatible road edges, stops, fleet assignments and authoritative passenger demand before it can be operational.


## Essential services, fleet and dispatch integration
The proposed municipal-service and utilities architecture is documented in [Capital Region Essential City Services & Utilities Atlas](CAPITAL_REGION_ESSENTIAL_CITY_SERVICES_AND_UTILITIES_ATLAS.md). Waste collection, fire/emergency response and maintenance fleets are future conceptual consumers of this fleet/trip system; they are not activated by this reference. Any operational trip must declare vehicle compatibility, crew/staff availability, road-edge restrictions, route graph version, stops/destination, trip lifecycle and idempotent completion. A blocked road must invalidate affected routes. A decorative truck, ambulance or patrol vehicle has no dispatch, collection or response effect. Existing vehicle catalog statuses remain unchanged.
