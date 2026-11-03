# Capital Region — Emergency Services, Fire, Police, Healthcare & Disaster Response

**Status:** Detailed design specification; documentation only, not approved for V1 implementation.  
**Authority:** The V1 content catalog remains the sole authority for operational IDs and release status. This document adds no operational IDs and changes no existing catalog status.

## 1. Product intent

Emergency services must be operational city systems, not decorative buildings or score-generating props. Fire stations, police stations and hospitals must serve a real catchment, have finite staffing and vehicle capacity, receive incidents, dispatch appropriate units, travel through the road/access network, arrive, perform work and return to service. Their absence or insufficiency must create visible, explainable service gaps and consequences.

The player's planning question is not simply "How many stations did I build?" but "Can the actual staffed and equipped network reach the people and assets exposed to risk, with enough capacity, in time?" A single station may be sufficient for a small, low-risk, well-connected settlement, but insufficient for a dense city even when physically nearby.

Design principles:
- Coverage depends on population, occupied buildings, risk, geography, road access, response travel time, staff, vehicles, equipment, operating state and simultaneous incidents.
- A station building does not equal an available response unit. A parked vehicle without a qualified crew is not dispatchable.
- Dispatch is not arrival; arrival is not containment, arrest, treatment or recovery.
- Emergency vehicles travel on the authoritative graph. No teleporting, instant arrival or routing through inaccessible terrain.
- Residents, visitors, workers and critical facilities use explicit non-duplicating demand contracts.
- Emergency response protects people and assets; it does not guarantee zero incidents or zero damage.
- Service score rewards effective preparedness and delivery, not station spam or decorative density.
- All numeric thresholds, capacities, staffing ratios, response-time targets, risk coefficients, vehicle counts, costs and scoring weights remain TBD.
- This document proposes no new V1 IDs and changes no existing catalog status.

## 2. Three distinct emergency-service domains

### 2.1 Fire and rescue

Fire-service incident candidates include structure fires, vehicle fires, vegetation fires, industrial incidents, rescue/extrication, hazardous-material response and severe-weather assistance. Which incident classes are supported must be explicitly approved.

A fire station may provide engines, ladder/apparatus, rescue units, specialist units and command capability only where the vehicle/equipment catalog authorizes them. Capability depends on assigned fleet, available crews, equipment, supplies, maintenance and access.

### 2.2 Police and public safety

Police incident candidates include residential burglary, theft, vandalism, public disturbance, traffic incident support, missing-person response and major public-safety incidents. Each supported class requires a defined detection/reporting, dispatch, investigation and resolution model.

A police station is not a magic prevention radius. Prevention may depend on patrol presence, response capability, neighborhood conditions, lighting/access and evidence-backed deterrence rules. A building with no staff or patrol units does not provide full protection.

### 2.3 Healthcare and ambulance response

Hospitals and healthcare facilities provide treatment capacity; ambulance bases or dispatch-capable facilities provide pre-hospital response if explicitly modeled. A hospital is not equivalent to an ambulance station, and an ambulance vehicle is not a hospital bed.

Healthcare capacity distinguishes emergency intake, staffed clinical capacity, beds, equipment, supplies and downstream treatment. Ambulance dispatch, on-scene stabilization, transport, hospital arrival, triage, treatment and discharge are separate events.

## 3. Demand, population density and exposure

Emergency demand must be based on actual city state, not the number of residential building objects alone.

Potential authoritative inputs:
- occupied resident population or approved household/cohort population;
- visitor presence and overnight guests, kept separate from permanent residents;
- worker and customer presence where modeled;
- building use, occupancy, floor/height/structure and condition;
- industrial/commercial hazards and stored materials where modeled;
- time of day, operating schedules and event crowd loads;
- weather and surface conditions where causal models are approved;
- historical incident rate only if derived from recorded simulation outcomes and a versioned model.

Population density is an exposure indicator: population divided by land area. It must use a clearly defined spatial unit and population snapshot. Do not mistake house count, residential capacity or zoning area for actual occupied population.

Density alone is not a complete risk model. Two districts with the same density may have different risk because of building use, construction, occupancy patterns, access, fire load, road connectivity and service availability. Keep these measures separate and explain their contribution.

For every district or service cell, maintain resident population and visitor presence separately; occupied building/use counts where available; exposure by incident class; incident demand/history; road/access quality and route reachability; available service capacity and current unit commitments; data coverage and confidence.

If occupancy or risk data is missing, show Unknown/Not modeled. Do not invent population by multiplying house count by an assumed household size.

## 4. Catchment and effective coverage model

Coverage is not a simple circular radius. A station may be geographically close but separated by disconnected roads, one-way restrictions, blocked bridges, congestion, terrain or inaccessible entrances. The canonical measure is route-based travel time from a dispatchable unit's current location to a valid incident access point.

Use a layered coverage model:
1. Geographic proximity: a visual hint, never proof of service.
2. Network reachability: a valid route exists on the current graph version.
3. Travel-time coverage: estimated route time under current traffic and road state.
4. Operational coverage: qualified crew, compatible vehicle, equipment, supplies and station readiness are available.
5. Concurrent coverage: remaining capacity after other incidents and commitments is considered.
6. Delivered response: actual arrival and response milestones are recorded after travel and work.

A district can be covered under current modeled conditions, reachable but delayed, partially covered/capacity constrained, uncovered/disconnected, temporarily degraded by committed units or station outage, or unknown because authoritative data is missing.

Do not display one misleading citywide percentage without its denominator, incident class, exposure weighting, time horizon and data coverage.

## 5. Station capacity, staffing and readiness

Effective capacity depends on station operating status and access; staffed shifts and qualified roles; available compatible vehicles; crew assignment; equipment and consumable stock; maintenance condition; fuel/energy; and simultaneous incident commitments.

Separate nominal fleet, assigned fleet, operational fleet, crewed fleet, available fleet, dispatched fleet, on-scene fleet and out-of-service fleet. The same vehicle or crew cannot serve two incidents simultaneously.

Station expansion is not useful if no staff, vehicles, supplies or road access exist. A station with available vehicles may still be unable to respond if the route is blocked or the incident requires unsupported specialist equipment.

## 6. Fire incident lifecycle

Proposed lifecycle:
reported/detected → validated → classified → prioritized → resources reserved → dispatched → en route → arrived → assessment → suppression/rescue → contained → overhaul/safety check → cleared → units returning → station ready → incident closed.

Distinguish ignition, detection delay, report delay, dispatch delay, travel, setup, suppression and recovery. Each stage may affect outcome, but numeric rates remain TBD.

Fire spread/damage must use a bounded model with explicit inputs, such as building construction/material class, occupancy/exposure, fuel/load where modeled, adjacency, wind/weather where approved, suppression actions and elapsed time. A fire must not jump arbitrarily across the map or spread because a visual flame effect touches another building.

Consequences may include condition damage, temporary closure, displacement, utility isolation, repair costs and service disruption. Injury/fatality should be included only through an approved non-graphic aggregate model. Do not add individual diagnoses or graphic depictions.

Suppression requires compatible resources and valid access. One engine may be sufficient for one incident under some conditions and inadequate for another; derive this from incident class, severity, affected area/building and available equipment, not a universal fixed rule.

## 7. Police incidents and residential burglary

Residential burglary must be an actual incident with a traceable lifecycle, not a random red icon or guaranteed loss event.

Proposed lifecycle:
risk exposure → incident opportunity → occurrence → detection/report → validation → priority → unit reservation → dispatch → en route → arrival → scene handling → investigation/evidence → resolved/unsolved → unit released → closure.

Separate prevention, detection, response and investigation. Patrol presence may influence risk only through an approved, explainable model. Police-station proximity alone cannot guarantee prevention. Lighting, access, occupancy and neighborhood activity are candidate factors only where authoritative systems exist.

A burglary may affect household/property condition, inventory/valuables if modeled, resident confidence and repair/recovery. Avoid inventing an unlimited pool of stolen goods or money. Any loss must be bounded by actual modeled property/economic state and recorded once.

Police response requires available qualified personnel, appropriate patrol vehicle or on-foot unit, valid route and incident compatibility. Some incidents require investigation rather than a siren response. Not every police movement should use emergency lights or sirens; use them only for authorized urgent dispatch states.

Do not portray police as omniscient: an unreported or undetected incident is not automatically known to dispatch. Distinguish estimated risk from confirmed incident.

## 8. Ambulance and hospital response

Proposed lifecycle:
emergency call → triage/validation → ambulance reservation → dispatch → en route → scene arrival → assessment/stabilization → transport decision → hospital route → arrival/hand-off → treatment queue → treatment → discharge/transfer → unit cleaned/restocked → available.

Hospital capacity distinguishes nominal beds/rooms, staffed beds, operational beds, available beds, occupied beds, emergency intake/triage capacity, specialist capability, equipment and supplies.

An ambulance may be available while the destination hospital is full or unable to provide required care. Select a valid destination under explicit rules, considering travel time and capacity; show diversion/transfer where modeled. No patient or vehicle teleports to a hospital.

A hospital without staffing, equipment, supplies or required utilities has reduced or unavailable effective capacity. A hospital does not automatically dispatch ambulances unless ambulance service is part of its approved facility contract.

Keep patient simulation abstract and privacy-preserving. Do not model real personal medical records or sensitive individual traits. Use anonymous incident/transport tokens and aggregate outcomes.

## 9. Emergency vehicle fleet and station garages

Vehicles are real mobile assets connected to the fleet registry and station assignments. Candidate classes include fire engine/pumper, aerial/ladder apparatus, rescue/extrication unit, police patrol car, ambulance, specialist medical response unit and command/support vehicle. These are candidates, not approved V1 IDs.

Each class needs a role contract: crew requirement, passenger/cargo/equipment capacity, road compatibility, dimensions/turning constraints, speed/acceleration/braking, fuel/energy, maintenance, animation states, emergency equipment, operating costs and service dependencies. All numeric values remain TBD.

Station garages physically and logically connect to the road network. Vehicles exit a valid bay/driveway, yield/merge according to the road model and enter the route graph. They must not materialize on the road or pass through buildings. Return-to-base uses a valid route and compatible available bay.

Vehicle states are explicit: parked, crew assignment pending, crewed/ready, dispatch reserved, exiting station, en route, on scene, working, transporting, returning, refueling/restocking, maintenance and out of service. Transitions are auditable and cannot duplicate a unit.

## 10. Emergency markings, identity, lights and sirens

The player should recognize the responding service at a glance. Fire, police and ambulance vehicles require distinct, coherent service liveries and markings:
- readable service name/emblem and vehicle role;
- high-contrast service-specific markings legible at mobile camera distance;
- appropriate reflective/visibility elements;
- correct placement and scale of badges, numbers and warning labels;
- roof light bars or beacons appropriate to vehicle class;
- headlamps, brake, indicator and reverse lights;
- siren speaker/audio source placement;
- service-specific equipment silhouettes without confusing one agency for another.

Do not use real-world official insignia or protected trademarks without permission. Create an original fictional municipal service identity consistent across station signs, vehicle liveries, uniforms, UI icons and dispatch alerts.

Emergency-light behavior is state-driven: off while parked/available unless authored station behavior applies; appropriate warning lights while responding; correct scene-safety behavior on arrival; off or reduced during normal return according to approved policy. Siren use is state- and urgency-dependent, not continuously active for every movement. Audio supports mute/volume/accessibility settings and avoids excessive repetition.

Vehicle animations include station-bay door, engine start/idle, light activation, departure, acceleration, turning, braking, scene stop, equipment/crew deployment, loading/transport, return and parking. These animations synchronize with authoritative vehicle states. VFX/audio cannot claim arrival or incident resolution ahead of simulation events.

## 11. Physical response choreography and traffic interaction

The response experience:
1. Incident appears in the city and dispatch UI.
2. Dispatch selects a qualified available unit.
3. Station alarm/crew preparation is shown where supported.
4. Garage door opens and vehicle exits the actual bay.
5. Vehicle merges into the road network and follows a valid route.
6. Traffic yields only under explicit emergency-priority rules.
7. Vehicle arrives at the correct access point, stops and enters on-scene state.
8. Crew/equipment activity reflects the assigned incident role.
9. After resolution, vehicle returns, restocks/cleans/repairs if required and becomes available again.

Traffic yielding is bounded and safe: no teleportation, phasing through traffic, instant lane changes or ignoring blocked routes. Emergency priority may affect signal control only if approved. Freight and public transport preserve their own route/capacity rules.

If the route is unavailable, vehicle blocked, station bay obstructed or destination inaccessible, expose a visible delay/failure reason and allow a valid alternate route or escalation where supported.

## 12. Natural disasters and multi-agency incident command

Candidate disaster classes include urban/vegetation fire, flood, severe storm, earthquake, infrastructure failure and hazardous-material event. Each requires its own trigger, footprint, exposed assets, impact model, response prerequisites and recovery rules. Listing a hazard does not approve it for V1.

Major incidents may require incident command and shared location/status; agency-specific task assignment; resource staging and access control; finite crews, vehicles, supplies and fuel; evacuation/shelter only if approved; utility isolation/restoration; healthcare surge and patient routing; road closures/detours; district recovery and finance.

A single incident may reserve resources from multiple stations, but reservation must be atomic and idempotent. No unit can be committed twice. Cascading incidents follow explicit dependency graphs; one fire cannot arbitrarily trigger every disaster type.

## 13. Service adequacy, coverage score and player feedback

The city should communicate whether emergency provision is adequate. Avoid a simplistic "one station = coverage" rule or a score that rises merely from placing more stations.

Separate diagnostics:
- population/exposure served by reachable stations;
- risk-weighted exposure by incident class;
- route-based estimated response-time bands;
- staffed/crewed available units;
- peak concurrent demand and reserve capacity;
- station/vehicle readiness and maintenance;
- actual incident response milestones;
- unresolved/unserved incidents;
- hospital effective capacity and intake pressure;
- district equity and data coverage.

A service-adequacy scorecard may combine versioned, explainable indicators. Formula, weights, thresholds and normalization remain TBD and require approval. Do not double-penalize the same underlying failure. Missing data is not zero performance; mark Not modeled or exclude it with visible coverage.

Consequences should be understandable:
- no nearby reachable fire station: greater modeled response delay and higher potential loss under the approved fire model;
- too few crews/vehicles for dense exposure: simultaneous incidents compete for limited units;
- no effective police coverage: higher modeled burglary risk or slower response only where the approved crime model supports it;
- insufficient hospital/ambulance capacity: longer queues, diversion or unmet care under the approved healthcare model;
- blocked roads or poor station placement: route-based coverage degrades even if map distance looks short.

Provide evidence-backed recommendations, e.g. "North district has high occupied exposure but only one available crew; a second simultaneous incident would be uncovered." Do not dictate arbitrary station counts.

## 14. Mobile-first player experience

Portrait-first screens:
- Emergency overview: active incidents, severity, agency, dispatch status and readiness.
- Coverage map: network/time catchments, exposure, uncovered pockets and route bottlenecks.
- Station detail: assigned/available vehicles, crews, shifts, equipment, bays, maintenance and commitments.
- Incident detail: reported facts, priority, affected assets, dispatch history, ETA forecast, actual arrival and resolution milestones.
- Fire overlay: affected buildings, spread state only if modeled, crews and access.
- Police overlay: risk estimate versus confirmed incidents, patrol coverage and case state.
- Healthcare overlay: ambulance availability, hospital intake, staffed beds and diversion state.
- Fleet panel: vehicle status, route, livery identity, lights/siren state and return/restock.
- Service scorecard: formula version, denominator, time horizon, confidence and district gaps.

Use large touch targets, safe areas, clear labels, legible map symbols and non-color-only status. Camera zoom and effects must not hide incident access points or dispatch controls. Provide accessible controls to reduce siren/audio intensity and flashing.

## 15. Professional visual asset and plugin pipeline

This is a high-visibility gameplay feature. Stations, garage bays, apparatus, police vehicles, ambulances, uniforms, equipment, signage, emergency lights and crews require professional coherent design—not generic placeholder cars with pasted icons.

Use specialist design and asset plugins/tools for station architecture and garage modules; original municipal emergency-service brand system; vehicle exterior design and livery; editable 3D modeling with correct proportions and equipment; wheels, suspension, doors, light bars and articulated components; material/UV authoring, glass, reflective markings and emissive light meshes; rigging and vehicle/crew animation; Cocos Creator prefabs, LODs, collision and mobile variants; siren, engine, radio and ambient sound authoring; scene integration and review.

All deliverables remain editable at source level. Each asset requires source project, export settings, scale/pivot, mesh/material/texture references, rig/animation contracts, prefab contract, LOD/collision, mobile shader constraints, provenance, explicit free commercial-use license and content hash. A concept render or AI image alone is not a runtime asset. No paid asset purchase is assumed.

## 16. Determinism, persistence and audit

Persist incident IDs/state/version, location/access point, cause/classification, exposure snapshot, station assignments, unit IDs, crew assignments, route graph version, dispatch/arrival/work milestones, damage/condition events, treatment/transport events, costs, resource reservations and closure evidence.

All dispatch/reservation/consumption/settlement operations require idempotency. Save/load cannot duplicate an incident, vehicle, patient transport, resource consumption, fine, repair cost or score impact. Replaying the same approved inputs must reproduce the same authoritative outcomes.

Audit must explain who/what initiated an incident, why a unit was selected, why alternatives were unavailable, what route/version was used, why response was delayed, what resources were consumed and why the incident closed.

## 17. Acceptance scenarios

1. A fire incident without reachable fire coverage is visibly uncovered and is not served by a teleporting unit.
2. Building more houses increases modeled exposure only through actual occupancy, not nominal housing capacity alone.
3. A single station becomes insufficient when occupied population/risk and concurrent incident demand exceed effective capacity.
4. A station with no crewed vehicle cannot dispatch a response unit.
5. A vehicle in maintenance or already assigned cannot be dispatched twice.
6. A nearby station separated by a disconnected road is not route-covered.
7. A blocked road changes route/ETA or produces a visible access failure.
8. A fire engine exits its real station bay and follows the road graph.
9. Fire suppression begins only after arrival and valid crew/equipment setup.
10. Fire spread/damage follows the approved causal model, not particle overlap.
11. A burglary is not automatically known to police before detection/report.
12. Police station proximity alone does not guarantee prevention or instant arrest.
13. Police patrol/response units have distinct livery and state-appropriate emergency signals.
14. An ambulance is not counted as a hospital bed.
15. A hospital with no staffed emergency capacity cannot accept unlimited arrivals.
16. An ambulance reaches a valid hospital destination through the route graph.
17. Patient transport and hospital handoff occur once and are persisted.
18. Fire, police and ambulance vehicles have unmistakable service-specific markings at mobile camera scale.
19. Sirens and emergency lights activate only under defined response policy and respect accessibility settings.
20. A vehicle returning from an incident is unavailable until required restock/cleaning/maintenance completes.
21. Two simultaneous incidents cannot reserve the same crew or vehicle.
22. Multi-agency resources are reserved atomically without duplicate allocation.
23. The coverage score exposes denominator, incident class, weighting version and missing data.
24. Decorative stations without staff/vehicles do not improve operational coverage.
25. Reducing visual effects quality does not change dispatch, route or incident outcomes.
26. Save/load during dispatch, on-scene work or patient transport creates no duplicate unit or event.
27. Mobile users can dispatch and inspect incidents without precision taps or obstructive overlays.
28. Low/mid-tier phone profiling validates vehicle, siren, lights and traffic rendering under load.

## 18. Unresolved decisions and implementation gate

Approved incident classes; resident/visitor exposure abstraction; district/cell resolution; risk model; station and agency IDs; facility service contracts; staffing and shift model; vehicle classes/IDs; crew/equipment compatibility; route/travel-time model; emergency traffic priority; fire spread/damage abstraction; burglary prevention/detection model; ambulance/hospital split; clinical capacity abstraction; disaster scope; coverage-score formula; response-time targets; service equity policy; visual brand identity; audio policy; device floor and performance budgets.

All quantities, coefficients, thresholds, response targets, costs, capacity values, vehicle parameters and score weights remain TBD. Before implementation:
1. approve incident/service/vehicle scope and IDs in the canonical catalog;
2. define authoritative population/exposure and occupancy sources;
3. define route-based catchment and concurrent-capacity contracts;
4. define fire, police and healthcare state machines;
5. integrate station/fleet/crew/resource reservations with existing allocation and crisis systems;
6. define scorecard formula and explainability;
7. approve original service brand and professional editable station/vehicle/crew assets via specialist tools/plugins;
8. verify free commercial licenses, provenance and hashes;
9. run mobile usability, accessibility, determinism and real-device performance tests;
10. obtain explicit approval to leave the design phase.

**Evidence status:** Documentation only. No station, emergency vehicle, fire, burglary, ambulance dispatch, hospital triage, siren, emergency light or disaster simulation is implemented or device-tested by this document. Existing V1 IDs and statuses remain unchanged.
