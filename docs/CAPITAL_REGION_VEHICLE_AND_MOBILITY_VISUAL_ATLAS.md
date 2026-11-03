# Capital Region Vehicle & Mobility Visual Atlas

**Status:** Detailed design specification / Draft; not an implementation claim.  
**Target:** Cocos Creator 3.8.6, TypeScript, Android and iOS, mobile-first.  
**Authority:** `CAPITAL_REGION_V1_CONTENT_CATALOG.md` defines V1 content status; `VEHICLE_FLEET_FREIGHT_TRAFFIC_SPEC.md` defines simulation contracts. This atlas defines visual production and presentation only.

> Vehicle IDs and scope in this document are copied from the existing fleet specification. No new operational vehicle class, capacity, dimensions, speed, turn radius, passenger count, budget or simulation feature is authorized here. Unknown values remain TBD.

## 1. Purpose and non-negotiable rules

The Capital region must show a believable, legible moving city while preserving the truth of the underlying economy and traffic simulation.

1. Every operational moving vehicle is a presentation of an authoritative trip, dispatch or service job.
2. A rendered vehicle never creates, completes, duplicates or cancels a trip.
3. Decorative vehicles are explicitly non-operational and cannot affect traffic counts, freight, service coverage, population, congestion, parking capacity or economy.
4. Vehicle geometry, collision/access envelopes and visual bounds are separate definitions.
5. Visible agent count is not the number of simulated trips. Aggregate flow remains authoritative when agents are not rendered.
6. A vehicle may not teleport through buildings, cross blocked edges, ignore a legal turn restriction or use an incompatible road.
7. No production asset is approved by a concept image alone. Editable mesh, materials, rig/animation where needed, LODs, prefab, manifest and device evidence are required.
8. V1 scope follows the content catalog and fleet specification; deferred or candidate features must not quietly become required gameplay.

## 2. Vehicle class registry and V1 scope

| Existing class ID | Existing fleet status | Intended visual identity | Required simulation link |
|---|---|---|---|
| `VEH-CITIZEN-CAR` | Candidate | Compact/general private passenger car; several generic silhouettes | Household/private trip only when candidate feature is enabled |
| `VEH-DELIVERY-VAN` | V1-Support | Small commercial panel van with readable cargo body | Workshop/factory pickup and delivery trip |
| `VEH-HEAVY-TRUCK` | Candidate | Rigid heavy goods truck; cab and cargo body clearly separable | Bulk freight, road restrictions and payload |
| `VEH-FIRE-ENGINE` | V1-Support | Emergency appliance with high-contrast generic markings | Fire incident dispatch and available response capacity |
| `VEH-POLICE-CAR` | V1-Support | Generic patrol vehicle, no real-world insignia | Police dispatch and service coverage |
| `VEH-AMBULANCE` | V1-Support | Generic medical response van/box body | Health incident dispatch and service capacity |
| `VEH-WASTE-TRUCK` | V1-Support | Collection body with loading/rear mechanism | Waste collection route, load and depot capacity |
| `VEH-CONSTRUCTION-TRUCK` | Candidate | Site-delivery truck with robust chassis | Construction material shipment and site access |
| `VEH-BUS` | Deferred | Urban bus silhouette only for future reference | No V1 passenger transport behavior |
| `VEH-DECORATIVE` | Decoration | Generic parked/ambient vehicle variants | No gameplay, trip, capacity or traffic effect |

The registry is not permission to activate Candidate or Deferred behavior. V1-Support vehicles are only rendered when their corresponding service/job system is actually available and has authoritative state.

## 3. Shared visual language and model contract

### 3.1 Silhouette families
- **Light utility:** delivery van, ambulance and future service vans must remain distinguishable by roof/body proportions and role-specific equipment, not tiny decals.
- **Passenger/patrol:** citizen car and police car use compact car proportions; police identity is limited to generic livery and roof equipment.
- **Heavy logistics:** heavy truck and construction truck must read as heavier vehicles through cab/body proportions and wheel grouping; no unapproved trailer articulation.
- **Special service:** fire engine and waste truck have unmistakable functional body shapes and visible access/loading equipment.
- **Bus:** reference-only while Deferred; no stops, passenger animation or route UI should imply a live system.

### 3.2 Required views for each vehicle asset
Every vehicle brief and review sheet must include:
1. front, rear, left, right and top orthographic views;
2. neutral three-quarter hero view at the in-game camera angle;
3. Far silhouette test at actual projected mobile size;
4. wheelbase/axle and ground-contact view;
5. light and signal state sheet;
6. animation pose/contact sheet;
7. collision/access envelope overlay;
8. palette/livery variants;
9. LOD comparison at identical framing;
10. in-engine screenshot on a representative street with mobile HUD and safe areas.

A polished hero render is not accepted if the vehicle is unreadable at gameplay scale.

### 3.3 Materials and color
Use a coherent city-wide material response: painted metal, glass, rubber, lamp lenses and cargo surfaces must have distinct roughness/reflectance behavior. Avoid excessive chrome, transparent glass surfaces, tiny text and high-frequency decals that shimmer on phones. Emergency role colors must maintain contrast in daylight and night scenes; color must not be the sole carrier of meaning. Exact palette values remain TBD pending moodboard and color-vision/accessibility review.

All liveries must be original and brand-neutral. Do not copy real automaker logos, protected vehicle graphics, emergency-service insignia or distinctive commercial fleet branding.

### 3.4 Geometry and transform contract
Each asset handoff records:
- stable asset key and source/license manifest;
- model origin, forward axis, up axis and unit scale;
- wheel pivot/socket positions and steering pivot;
- lamp, beacon, door and loading mechanism sockets where relevant;
- visual bounds, collision envelope and route/access envelope separately;
- material slots and texture references;
- LOD/impostor variants and transition evidence;
- prefab hierarchy and animation controller contract.

Exact dimensions, wheel count for unconfirmed configurations, clearance and turning envelope remain TBD until spatial simulation and physical-device review.

## 4. Class-specific art and behavior briefs

### 4.1 `VEH-DELIVERY-VAN` — V1-Support
**Visual read:** compact panel van; cab separated from enclosed cargo volume; rear and side loading doors; restrained generic fleet markings.  
**Required states:** parked at legal dock, queued for dispatch, departing, cruising, slowing, stopped at junction, backing/positioning only if collision-safe support exists, loading, unloading, rerouting, completed and unavailable.  
**Gameplay truth:** cargo is reserved at source and destination before dispatch; load/unload animation is presentation of transaction state, never the transaction itself.  
**Do not show:** cargo appearing/disappearing without ledger update, loading at an arbitrary curb, or a delivery van completing a trip while its authoritative trip is pending.

### 4.2 `VEH-FIRE-ENGINE` — V1-Support
**Visual read:** robust emergency body with hose/equipment compartments and generic beacon/lightbar.  
**Required states:** station-bay idle, dispatch-ready, responding, stopped/arrived, incident support, returning, maintenance and unavailable.  
**Lights/sound:** beacon, siren and flashing patterns only while the corresponding dispatch/incident state authorizes them; respect audio accessibility controls.  
**Gameplay truth:** response is constrained by station availability, vehicle availability, route reachability and incident capacity. A visible engine cannot imply response coverage when no unit is available.

### 4.3 `VEH-POLICE-CAR` — V1-Support
**Visual read:** generic patrol car with subtle roof equipment and abstract, non-real insignia.  
**Required states:** station idle, patrol/dispatch only if the job exists, response, arrival, return and unavailable.  
**Gameplay truth:** patrol visuals do not independently increase safety or service coverage. No random police chase or siren without an authorized event.

### 4.4 `VEH-AMBULANCE` — V1-Support
**Visual read:** high-roof response vehicle or compact box ambulance; clear medical role through generic symbols and high contrast.  
**Required states:** bay idle, dispatched, responding, arrived, patient/service transfer only if modeled, returning and maintenance.  
**Gameplay truth:** no passenger/patient count, health outcome or clinic capacity may be inferred from the rendered vehicle alone.

### 4.5 `VEH-WASTE-TRUCK` — V1-Support
**Visual read:** collection body with a recognizable rear/side loading mechanism; robust utility tires and generic municipal livery.  
**Required states:** depot idle, collection route, stop/collection, capacity-constrained, unloading at depot, return and maintenance.  
**Gameplay truth:** collection changes waste stock only through authoritative stop/job completion. If the truck is full or depot capacity is unavailable, the UI and simulation expose the blockage; the truck must not visually erase waste.

### 4.6 `VEH-CITIZEN-CAR` — Candidate
**Visual read:** generic compact, sedan and small utility silhouettes may be explored, but no production count or fleet composition is fixed.  
**Required states if enabled:** trip queued, assigned, driving, waiting, parking, parked, returning and cancelled.  
**Gameplay truth:** household travel demand and parking occupancy must come from the household/trip model. Do not spawn arbitrary cars and count them as population mobility.

### 4.7 `VEH-HEAVY-TRUCK` — Candidate
**Visual read:** heavy cab and rigid cargo body; optional trailer only after articulated vehicle support is designed and tested.  
**Required states if enabled:** freight assignment, loading, route travel, restricted turn/road handling, dock approach, unloading and return.  
**Gameplay truth:** payload, road compatibility and turning/access envelopes are checked before assignment. A visually small truck cannot bypass heavy-vehicle restrictions.

### 4.8 `VEH-CONSTRUCTION-TRUCK` — Candidate
**Visual read:** site logistics truck; cargo body and safety equipment distinguish it from ordinary freight.  
**Required states if enabled:** material dispatch, site approach, unload, return and unavailable.  
**Gameplay truth:** construction materials are delivered to a valid project reservation. No truck animation may advance construction or consume materials without the project transaction.

### 4.9 `VEH-BUS` — Deferred
Reference-only art exploration may establish a generic city bus silhouette. Do not ship active routes, stops, passenger counts, transit coverage or bus UI until public transport is formally moved into scope and its simulation specification is approved.

### 4.10 `VEH-DECORATIVE` — Decoration
May appear parked in authored legal parking spaces or as a sparse non-blocking ambience element. Must be marked decorative in data and QA. It has no trip ID, cargo, passengers, collision that blocks routes, parking occupancy, congestion contribution or service effect. Decorative cars must not be animated as though they are actively completing jobs.

## 5. Motion, animation and state synchronization

### 5.1 Common motion states
Visual animation consumes a read-only presentation snapshot of the authoritative vehicle/trip state:
- stationary/engine idle;
- accelerate and cruise;
- brake/decelerate;
- legal turn;
- stop/wait at junction;
- dock approach and alignment;
- loading/unloading mechanism;
- emergency response signaling;
- return/depot arrival;
- disabled/maintenance.

Not every class supports every state. The class animation matrix must explicitly mark supported, unsupported and TBD states; unsupported animations must not be approximated with misleading generic loops.

### 5.2 Wheels, steering and body motion
Wheel rotation follows traveled distance, not frame count. Steering angle follows route curvature and is clamped to the validated steering envelope. Body pitch/roll is subtle and presentation-only. Wheel animation, suspension and shadows must not cause visible ground penetration or sliding. Simulation tick and render frame rate remain independent.

### 5.3 Signals and lights
- Brake lamps follow braking/stop state.
- Indicators follow an imminent legal route turn and stop after the turn.
- Head/tail lamps follow the supported time/light state.
- Emergency beacons and sirens follow authorized dispatch state.
- Reverse lamps only appear when a supported reverse maneuver is actually occurring.
- No decorative signal may contradict route direction or traffic controller state.

### 5.4 Audio and accessibility
Engine, tire, loading, siren and ambient sounds are distance/importance attenuated and pooled. Provide independent sound controls and a reduced-flashing option. Siren is not a constant loop. Critical dispatch information must also be communicated through text/icon/state, not audio alone.

## 6. Road use, intersections and conflict handling

The road graph and traffic controller remain authoritative. The visual layer must not invent lane topology.

- Vehicle class compatibility is checked against each edge before route assignment.
- Legal turn connections and intersection priority are read from graph/controller state.
- Stop lines, arrows, signals and crossing markings match the actual supported rules.
- Queue visuals are sampled from authoritative flow/vehicle states; no vehicle may jump the queue because of render ordering.
- A blocked edge triggers the simulation's deterministic reroute or failure policy; the visual vehicle follows the result.
- No per-frame full-graph pathfinding. Route updates follow graph version and bounded replanning policy.
- Near intersection animation may use simplified conflict visualization, but cannot grant right-of-way absent from the controller.

Exact lane count, lane width, vehicle speed, headway, junction timing and turn radius remain TBD until validated against the spatial graph and device performance.

## 7. Parking, curb access and service yards

### 7.1 Parking truth
A parked operational vehicle requires a valid parking/stop allocation if the parking system is enabled. A decorative parked vehicle occupies only an authored decorative slot and never consumes simulated capacity. Do not place parked cars on sidewalks, crossings, building access, fire lanes, freight aprons or road graph edges.

### 7.2 Loading and unloading
A dock defines compatible vehicle classes, approach direction, clearance envelope, reservation and service state. Dock animations start only after a valid job reaches the loading/unloading state. If no dock system exists for a building, use an explicitly designed abstraction rather than pretending the vehicle can load anywhere.

### 7.3 Emergency access
Fire, police and ambulance access must not be blocked by decorative props or parked vehicles. Emergency route exceptions, if any, must be explicit simulation rules, not visual clipping or teleportation.

### 7.4 Depot yards
Waste depot and emergency station visual yards must be consistent with available fleet/job state. Empty bays remain empty; do not populate every bay with decorative vehicles in a way that implies additional capacity.

## 8. Pedestrians and crossings

The existing V1 content catalog does not define a pedestrian vehicle class or a full pedestrian simulation. Therefore:
- pedestrians are not added as a new operational vehicle ID;
- an operational pedestrian agent requires an approved pedestrian trip/graph and crossing controller;
- crossing occurs only at a supported crossing and valid signal/priority state;
- no pedestrian may appear inside a moving vehicle path or cross a closed road;
- decorative idle pedestrians, if later approved, are sparse, explicitly non-operational and excluded from population, satisfaction, service, commerce and traffic metrics;
- crowds, queues and shop visitors must not imply visit demand or service throughput without a real event.

Pedestrian simulation scope, accessibility routing, group representation and agent budgets remain TBD pending a dedicated design decision.

## 9. Traffic fidelity and camera-distance presentation

Use the three fidelity tiers already defined in the fleet specification:

| Tier | Authoritative representation | Visual presentation |
|---|---|---|
| A — Aggregate | Edge flow counts and average travel cost | Optional low-cost flow hints; no individual vehicle claims |
| B — Sampled agents | Selected authoritative trips | Pooled visible vehicle prefabs; trip identity remains stable |
| C — Focused simulation | Nearby intersections/incidents | Detailed movement and conflict presentation for selected agents |

Switching tier must preserve trip progress, reservations, ETA/outcome and deterministic state. Culling a vehicle must not cancel its trip. Reappearance must restore its correct route progress without duplication.

### 9.1 Distance bands
- **Far:** aggregated flow, low-cost impostor or no individual vehicle.
- **Mid:** simplified mesh/LOD, reduced animation and pooled update.
- **Near:** full approved prefab, wheel/light animation and relevant interaction.
- **Selected/incident focus:** temporary detail increase only within measured device budget.

Actual distance thresholds, visible-agent caps, spawn density, update intervals, batching and memory budgets are TBD until profiling on representative low-, mid- and high-tier phones.

## 10. Lighting, weather and day/night

Vehicle lights must be readable without excessive real-time lights. Use emissive materials and tightly bounded light sources where necessary. Far lights may use emissive impostors. Night presentation must not reveal fictitious trips or service availability.

Weather effects remain visual-only unless a separately approved simulation contract defines their effect on speed, road condition, incidents or maintenance. Do not reduce speed, alter ETA or create hazards merely because a rain particle effect is visible.

## 11. Specialist tool and plugin production pipeline

A professional vehicle must be produced through editable specialist workflows, not a single generated image.

1. **Reference research:** original silhouette boards, source URLs, creator, acquisition date, license and restrictions.
2. **Concept and proportion:** vehicle family exploration and orthographic proportion sheet.
3. **3D blockout/modeling:** Blender or equivalent editable 3D authoring; verify wheelbase, ground contact and access envelope.
4. **Materials:** UV layout, texture packing, trim sheets and mobile-friendly material variants.
5. **Rig/animation:** wheel, steering, doors, beacon and loading mechanism rigs only where the class needs them.
6. **Optimization:** LODs, impostors, mesh/material consolidation and texture-size review.
7. **Engine integration:** import into Cocos Creator, create reusable prefabs, animation/state bindings, sockets and colliders.
8. **Automated validation:** naming, missing material, bounds, scale, pivot, LOD presence, animation references and license manifest.
9. **Device review:** capture actual phone screenshots/video and profile frame time, memory and thermal behavior.
10. **Evidence:** retain editable source project, exported runtime files, manifest, test results and reviewer sign-off.

AI image generation may support ideation/reference only. It does not replace mesh topology, UVs, materials, rig, animation, prefab, collision/access data or licensing evidence. Use specialized plugins where they provide editable deliverables; do not accept a flattened image as an implementation artifact.

## 12. Asset provenance and license gate

Every external asset record must include asset key, exact source page, creator, package/file name, acquisition date, license text/version, commercial-use permission, attribution obligations, modification/redistribution restrictions, source archive hash (SHA-256), extracted file hashes and reviewer decision.

A pack-level license statement is insufficient if individual files carry different terms. Unknown or ambiguous terms block integration. Keep original license files and attribution notices with the asset. Do not assume that free download means unrestricted commercial use.

## 13. Cocos prefab and data contract

Conceptual minimum (not a finalized runtime API):

```ts
interface VehicleVisualDefinition {
  vehicleClassId: string;       // must match fleet registry
  assetKey: string;
  prefabKey: string;
  materialSetKey: string;
  lodProfileKey: string;
  animationProfileKey?: string;
  audioProfileKey?: string;
  visualBoundsKey: string;
  collisionEnvelopeKey: string;
  accessEnvelopeKey: string;
  supportedVisualStates: string[];
  decorativeOnly: boolean;
  provenanceManifestKey: string;
  acceptanceSuiteId: string;
}
```

Runtime presentation input is read-only and includes stable vehicle/trip identity, class, route segment/progress, movement state, authorized light/sound state and simulation timestamp. Visual components cannot write cargo, trip completion, dispatch, parking allocation or economic ledger state.

Validation must reject unknown class IDs, missing prefabs, missing LODs, incompatible animation states, unlicensed assets, negative/invalid bounds and a decorative definition that contains operational capabilities.

## 14. Mobile performance and quality gates

No numeric budget is invented here. Measure on representative Android and iOS devices and record device model, OS, build, scene density, camera distance, quality profile, frame-time distribution, memory, thermal state and test duration.

Required profiling scenarios:
- quiet residential street;
- mixed commercial intersection;
- industrial freight dock with heavy vehicles if enabled;
- emergency response scene;
- maximum supported visible-agent stress scene;
- camera zoom transitions and background/resume;
- Low/Medium/High visual profiles where supported.

Optimization order: reduce unnecessary visible agents; pool prefabs; simplify far LOD; reduce animation update rate by distance; share materials; minimize real-time lights/shadows; avoid per-frame graph/path work; test thermal stability. Never hide simulation failures by merely culling visible vehicles.

## 15. Acceptance matrix

| Gate | Pass condition | Evidence |
|---|---|---|
| Registry integrity | Every class matches the fleet spec and catalog scope | ID audit |
| Visual identity | Each enabled class is distinguishable at gameplay scale | Silhouette sheet and phone capture |
| Geometric integrity | Scale, pivot, wheel contact and bounds are valid | Automated report and 3D review |
| State truth | Lights, animation and loading match authoritative state | State-transition test/video |
| Route integrity | No illegal edge, turn, collision or teleport | Deterministic route test |
| Freight integrity | Load/unload commits exactly once | Ledger/idempotency test |
| Service integrity | Emergency vehicle availability and response match dispatch | Dispatch integration test |
| Parking integrity | No blocked road, crossing, dock or emergency access | Spatial validation |
| Fidelity switching | Aggregate/sampled/focused tiers preserve outcomes | Tier-switch regression |
| Save/resume | Active trip resumes once after reload/background | Save/load test |
| License | Every file has traceable compatible rights | Manifest and license review |
| Mobile quality | Meets approved device budgets without thermal regression | Device profile report |
| Accessibility | Important states do not rely on color/audio/flashing alone | Accessibility review |

A class is not Approved until all applicable gates pass. Approved art, engine-integrated prefab and device-verified status are separate milestones.

## 16. Open decisions (remain TBD)

- Final vehicle dimensions, mass, wheelbase, collision/access envelopes and turning radii.
- Road/lane dimensions, speeds, headway and signal timing.
- Parking system scope and legal curb allocation.
- Whether citizen travel and heavy freight candidates enter V1.
- Pedestrian simulation and accessibility-routing scope.
- Time-of-day and weather simulation rules.
- Vehicle visual palette and livery system.
- LOD thresholds, visible-agent caps, animation rates and memory/frame budgets.
- Exact asset sources and per-file license decisions.
- Device test matrix and minimum supported phone profile.

Each decision requires an owner, evidence and explicit approval before becoming a production constant.

## 17. Current completion statement

This atlas is a design and production handoff specification only. It does not claim that vehicle meshes, rigs, animations, Cocos prefabs, pedestrian systems, parking logic, traffic simulation, asset downloads or device tests have been completed. The existing fleet simulation document remains authoritative for operational behavior. The city-building implementation gate remains unchanged.
