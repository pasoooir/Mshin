# Capital Region — Weather, Seasons, Day/Night & Environmental Impacts

**Status:** Design specification only; not approved for V1 implementation.  
**Authority:** The V1 content catalog remains authoritative for operational IDs and release status. This document adds no operational IDs and changes no V1 status.

## 1. Mission and simulation principles

Create a coherent, readable environmental simulation in which time of day, calendar, seasons and weather affect the city through explicit causal systems. The goal is not a decorative skybox or random rain particle effect: environmental conditions must influence visibility, comfort, energy demand, mobility, outdoor activity, water systems, public health, tourism and emergency readiness only where those systems are modeled and approved.

Core invariants:
- Visual weather is a presentation of authoritative environment state, not an independent source of truth.
- A forecast is not observed weather; a warning is not an incident; a hazard is not automatically damage.
- Weather effects must be bounded, explainable, deterministic under replay and traceable to source state.
- Time, calendar, season and weather are distinct concepts. Season is not a substitute for actual weather.
- Do not assume real-world meteorological accuracy, climate geography or local seasonal patterns without an approved world setting and data model.
- No arbitrary numeric temperature, rainfall, wind, humidity, daylight, probability, damage, energy multiplier or seasonal duration. All parameters remain TBD pending design approval and calibration.
- Weather cannot create or destroy inventory, money, residents, visitors, vehicles or infrastructure without explicit authoritative events.
- Decorative clouds, snow, rain, fog, lightning, leaves, puddles and lighting cannot directly change simulation values.
- Missing environmental data must be represented as Unknown/Not modeled, not silently replaced with plausible-looking fabricated data.

## 2. Time authority, calendar and clock

Define one authoritative simulation clock with a versioned calendar. Separate:
- simulation tick/elapsed time;
- in-game date and local clock;
- day/night phase;
- calendar season or authored seasonal phase;
- weather observation interval;
- forecast horizon and issue time;
- event and operating schedules.

The clock must have a single owner and explicit pause, speed, save/load and offline catch-up semantics. UI animations, device wall-clock changes and app backgrounding must not independently advance or rewind authoritative simulation time.

A time configuration must define calendar origin, day length, season boundaries, leap/calendar rules if applicable, time-zone policy for the fictional world, schedule evaluation and migration/version behavior. These are unresolved decisions; do not choose a day length or season duration by intuition.

Schedules use simulation-local time and explicit intervals. Opening hours, worker shifts, traffic signals, lighting, service operations, events, visitor itineraries and maintenance windows must reference the same clock authority. Boundary handling must be deterministic: a facility must not open twice or skip a transition when save/load occurs exactly at a boundary.

## 3. Day/night cycle

The day/night system defines a continuous solar-light phase and discrete readable states such as dawn, daytime, dusk and night. The exact astronomical model, latitude, axial tilt and seasonal solar path depend on the approved fictional geography and remain unresolved.

Separate physical/visual light from operational schedules:
- ambient and directional lighting;
- sky and horizon appearance;
- artificial street/building lighting;
- window and signage illumination;
- headlamps and traffic signal visibility;
- building and public-space operating hours;
- worker/visitor activity schedules.

Nightfall must not automatically close every business, stop all traffic or disable services. Each venue/service follows its own authored schedule and staffing. Artificial lights require power only if power dependency is explicitly modeled. A power outage may affect illumination only through the authoritative electrical network; a dark-looking prop alone cannot imply an outage.

Day/night can inform visibility, comfort, outdoor use and lighting demand only through approved models. It must not secretly modify productivity, happiness, safety or prices via an opaque multiplier.

## 4. Seasons and calendar events

Seasonal phases are authored calendar states. Their names, duration, transition dates and regional applicability require approval. The simulation must support either a simplified fictional season calendar or a richer climate model, but must not mix both without clear authority.

Potential seasonal influences—only when supported—include daylight duration, temperature distribution, precipitation type, vegetation appearance, outdoor recreation, visitor demand, heating/cooling demand, agriculture and maintenance. A seasonal visual palette is not evidence that these gameplay effects are active.

Season transitions must be gradual or explicitly event-driven according to the chosen model. They must not reset stock, demand, budgets, resident needs or building condition. Seasonal events and holidays are authored content, not random free-revenue generators.

## 5. Weather state and observations

Weather state should be represented by independently versioned variables only where the simulation needs them. Candidate dimensions include:
- air temperature and perceived thermal conditions;
- precipitation type, intensity and accumulation;
- wind speed/direction and gusts;
- humidity;
- cloud cover and visibility;
- fog and atmospheric conditions;
- surface wetness, snow/ice accumulation and drainage state;
- severe-weather alerts.

Each variable requires units, valid range, spatial/temporal resolution, source, observation timestamp, confidence/quality and missing-data behavior. Do not add variables simply because a weather dashboard commonly displays them.

Observed/current weather, forecast, climatological baseline and scripted event must be separate data products. Forecasts include issue time, valid interval, horizon, uncertainty and version. A forecast must never be presented as actual conditions. A stale forecast must be visibly marked.

## 6. Weather generation and spatial consistency

Choose and document one weather authority before implementation:
1. authored deterministic weather sequences for controlled gameplay;
2. bounded procedural weather generated from approved climate/region parameters;
3. externally sourced real weather (only if the fictional world and product dependency explicitly justify it).

Do not combine sources opportunistically. The selected model must be reproducible for a saved simulation and have clear behavior after offline catch-up.

Weather can be spatially uniform in an early abstraction or use bounded zones/cells later. If spatial variation exists, define cell identity, interpolation, transition continuity and sampling rules. Do not show a storm over a district while its authoritative state reports clear conditions.

Weather transitions must have plausible continuity without unbounded random jumps. Severe events require explicit start, peak, decay and end states, with forecast confidence separate from actual severity. Numeric thresholds and transition rates remain TBD.

## 7. Surface and environmental state

Weather may alter surfaces through explicit state transitions: dry, wet, puddled, snow-covered, icy, flooded or obstructed—only if those states are modeled. Visual decals and shaders must reflect the authoritative surface state.

Surface state must have bounded persistence and recovery rules. Rain does not automatically create flooding; flooding requires rainfall/runoff, drainage/network capacity, terrain and explicit water-flow rules. Snow does not automatically create ice; ice requires a modeled condition. No surface state may appear solely because a particle effect is enabled.

Terrain elevation, slope, soil/permeability and drainage are prerequisites for credible runoff/flood modeling. If those systems are not available, show rain and weather without claiming hydrological simulation.

## 8. Mobility, traffic and road safety

Environmental conditions may affect travel only through explicit vehicle/road rules. Potential effects include visibility, braking distance, safe speed, route availability, congestion, walking comfort, bicycle access and incident risk. Each requires defined inputs and evidence-backed parameterization.

- Rain or fog does not automatically cause crashes.
- Snow/ice affects a road only if its surface state and maintenance model support it.
- A road closure requires an explicit authoritative closure event and responsible cause.
- Travel-time changes are forecasts until observed trips complete.
- Emergency vehicles must obey route/access constraints; weather does not teleport them.
- Freight and passenger transport share only the infrastructure rules they explicitly reference.

Road maintenance may include inspection, gritting, snow clearance, drainage clearing or debris removal as candidate tasks. They are not enabled until vehicle/equipment, workforce, material, route and funding prerequisites are modeled and approved.

## 9. Electricity, water, drainage and essential services

Weather-related load and disruption must be connected to authoritative utility models:
- heating/cooling demand only if building energy systems are modeled;
- electricity generation/network stress only through actual supply, distribution and demand;
- water demand or supply changes only through explicit consumption/storage/source rules;
- runoff and flood risk only through terrain, precipitation, drainage and capacity;
- wastewater overflow only through network capacity and operational state;
- waste collection disruption only through route/access and service schedules.

A storm graphic cannot cause an outage. An outage must originate from a modeled incident, asset failure or approved supply imbalance and follow the utility incident lifecycle. Service restoration requires actual repair/supply evidence.

## 10. Buildings, residents and workforce

Indoor comfort, heating/cooling, building envelope, weatherproofing and energy efficiency are potential systems. If implemented, separate building type, condition, occupancy, equipment, energy source and delivered comfort. A building's visual snow cover must not imply indoor heating failure.

Resident exposure and comfort must be modeled with explicit cohorts/household abstractions and time intervals. Do not infer health status or sensitive personal traits. Outdoor workers, construction, maintenance and service crews may face weather constraints only when safety rules, protective equipment, shift policies and dispatch requirements are defined.

Weather must not arbitrarily reduce all worker productivity. Any operational effect requires a causal rule, scope, interval, explainable UI and acceptance tests.

## 11. Agriculture, parks and vegetation

Agriculture, crop growth, soil moisture, irrigation, frost, heat stress and harvest windows are candidate systems requiring catalog approval and their own lifecycle specification. Weather does not create crops, yields or food inventory automatically.

Parks and vegetation may have seasonal appearance, irrigation demand, maintenance and storm damage only if corresponding asset and service models exist. Decorative foliage changes cannot be counted as ecological improvement, biodiversity, carbon capture or city-score gain.

## 12. Tourism, events and outdoor activity

Weather and day/night can influence visitor choice, attraction accessibility, outdoor venue operations, event capacity, itinerary changes and cancellations. These effects must be explicit and segment/venue-specific. A forecast may inform planning; actual conditions govern real-time operation under the approved policy.

Outdoor events require weather contingency, shelter/evacuation plan, safe capacity, staff and cancellation rules. Weather cannot produce guaranteed tourism booms or free spending. Indoor venues may remain open under conditions that close outdoor areas, subject to access, utilities and safety.

Tourism demand effects must not feed back into the same simulation interval in a circular loop. Visitor choice uses a prior published forecast/version; observed weather affects later trip decisions.

## 13. Health, emergency and public safety

Potential weather-related health or safety effects include heat/cold exposure, air/visibility hazards, flooding, wind damage and lightning risk. These require explicit, non-sensitive aggregate models and qualified service capacity. Do not simulate individual diagnoses or infer medical status.

Warnings, alerts, incidents, dispatch, arrival, containment and recovery are distinct states. An alert is not an incident; a forecast is not a confirmed hazard; dispatch is not arrival. Emergency response requires qualified available staff, compatible vehicles/equipment, supplies, valid route, access and funding as specified in the existing crisis/essential-services architecture.

Protect evacuation access and emergency routes. If hazard modeling is not available, expose the limitation rather than implying a complete disaster simulation.

## 14. Environment, pollution and sustainability

Air quality, noise, heat-island effects, emissions, water quality and ecological measures are separate domains. Weather may affect dispersion or thermal conditions only if a supported environmental model exists. Rain animation does not clean pollution; trees do not automatically offset emissions; night lighting does not itself measure energy consumption.

Each environmental metric needs authoritative sources, units, geographic coverage, time window, uncertainty and calculation version. Missing data is excluded or marked Not modeled according to the metric contract. Do not collapse unlike indicators into a fabricated green score.

## 15. Hazards, incidents and resilience

Potential hazards include severe wind, heat/cold waves, heavy precipitation, flooding, snow/ice, lightning and visibility events. These are candidates, not an automatic promise that all disasters are in V1.

Each approved hazard requires:
- trigger/source and confidence;
- geographic footprint and duration;
- warning lifecycle;
- exposed assets/population/service cohorts;
- vulnerability and impact model;
- prevention/readiness actions;
- incident and dispatch links;
- damage/condition evidence;
- recovery/repair and cost accounting;
- post-event audit and learning metrics.

No damage occurs without an authoritative impact event. Repair consumes valid materials, staff, vehicles, access and funds. Insurance, disaster aid, compensation, evacuation shelters and emergency reserves require separate finance/catalog approval.

## 16. Mobile UX and visual presentation

Mobile-first views:
- compact time/date and day-phase indicator;
- weather now card with units, timestamp and confidence;
- forecast timeline with clear actual/forecast separation;
- seasonal calendar and authored events;
- weather map/overlay with legend and data coverage;
- district impact summary for traffic, utilities, services and tourism;
- incident/warning inbox with severity, location, source and status;
- building/road/utility detail showing causal impact and recommended action;
- environmental dashboard with raw indicators and missing-data state.

Use large touch targets, portrait-first layouts, clear localized units, accessible labels, non-color-only status, readable contrast and low-motion alternatives. Avoid blocking the city view with excessive HUD. Weather intensity must not obscure critical interaction or accessibility.

## 17. Visual assets, effects and specialist tooling

Professional visual quality is required: sky and cloud layers, sun/moon path, dawn/dusk lighting, rain/snow/fog, wet/icy surfaces, puddles, wind-reactive foliage, seasonal vegetation, building lights, vehicle lights and hazard indicators.

Use specialist design tools/plugins for editable source assets, shader authoring, material/texture work, animation, lighting, prefab composition, optimization and review. AI-generated concept imagery alone is not a runtime implementation asset.

Every runtime deliverable retains editable source, shader/material parameters, texture provenance, scale, LOD, platform variants, prefab contract, effect-state mapping, license, source URL, author/creator and content hash. Use only assets with explicit free commercial-use rights unless separately approved. No paid asset purchase is assumed.

Effects must be state-driven and bounded. Use GPU particles/shaders where suitable, pooled emitters, screen-space limits, quality tiers, deterministic seeds where effects need replay, and reduced effects on low-end devices. Avoid full-screen expensive post-processing as a default. Do not invent polygon, particle, texture, memory or frame-time budgets; measure on the agreed minimum Android/iOS devices.

## 18. Determinism, persistence and offline behavior

Persist authoritative clock/calendar state, weather generator state or authored sequence index, weather observations, forecast versions, surface state where modeled, warnings/incidents, schedule transitions and relevant causal events.

Save/load must not duplicate time transitions, weather events, damage, service demand or repair costs. Offline catch-up must use a documented bounded policy and produce the same authoritative outcome as equivalent simulated ticks. Device wall-clock changes and app suspension cannot silently create extra days or weather cycles.

All random generation must use versioned deterministic seeds and bounded event streams. Changing a weather algorithm requires versioning/migration rules for existing saves.

## 19. Performance and quality strategy

Profile simulation cost separately from rendering cost. Environmental simulation should update at justified intervals and use spatial aggregation where possible. Visual weather quality tiers must not alter authoritative outcomes.

Measure on representative low-, mid- and high-tier supported phones:
- simulation tick cost and determinism;
- rendering frame time under rain/snow/fog/night lights;
- memory and texture residency;
- particle overdraw and fill rate;
- battery/thermal behavior;
- scene transition and background/resume behavior;
- touch responsiveness and text readability.

Exact device floor, budgets, update intervals, active effect caps and quality tiers remain TBD until hardware and profiling evidence are approved.

## 20. Acceptance scenarios

1. Pausing the simulation freezes authoritative time and weather transitions.
2. Save/load at a day/night boundary does not duplicate or skip schedule transitions.
3. Changing device wall clock does not alter simulation time.
4. A forecast is visibly distinct from observed weather and carries issue/valid times.
5. Stale or missing weather data is marked, not silently fabricated.
6. A season transition does not reset inventory, budgets or population.
7. Nightfall does not close unscheduled 24-hour services.
8. A visual power-lit window cannot contradict an authoritative outage state.
9. Rain particles alone do not create wet roads or flooding.
10. Flooding requires modeled runoff/drainage/capacity evidence.
11. Snow/ice affects traffic only when authoritative road-surface state exists.
12. A road closure requires a recorded closure event and cause.
13. A weather forecast cannot directly cause realized damage.
14. Severe weather warning, hazard, incident and damage remain distinct.
15. Emergency dispatch cannot teleport or ignore route/access constraints.
16. Weather-related utility outage follows the utility incident and restoration lifecycle.
17. Weather changes visitor choices only through approved attraction/itinerary rules.
18. Outdoor event cancellation respects authored safety policy and capacity.
19. Weather effects do not create unbounded same-tick tourism/traffic feedback loops.
20. Vegetation visual changes do not grant unmodeled ecological score.
21. Low-quality visual settings preserve identical simulation outcomes.
22. Replay with the same saved seed and inputs reproduces the same authoritative weather sequence.
23. Offline catch-up does not duplicate days, incidents, damage or costs.
24. Small-screen weather and warning controls remain accessible and usable.
25. Mobile performance is measured under worst approved environmental rendering conditions.

## 21. Unresolved decisions and implementation gate

World geography and latitude; calendar origin/time zone; day length; season model and duration; weather authority; spatial resolution; variables and units; forecast horizon/confidence; deterministic generation; surface/terrain/drainage model; which operational systems consume weather; hazard scope; environmental indicators; offline catch-up policy; supported device floor; visual quality tiers; performance budgets.

All numeric values and thresholds remain TBD. Before implementation, approve the world/time model and weather authority; choose the minimal V1 variable set; map every gameplay effect to an authoritative system; approve hazard scope and catalog entries; define deterministic persistence/migration; produce editable specialist-tool/plugin assets and shaders with licenses/provenance/hashes; test accessibility and real-device performance on mobile; obtain explicit approval to leave design phase.

**Evidence status:** Documentation only. No clock, weather generator, season simulation, environmental hazard, weather shader or device test is implemented or claimed by this specification. Existing V1 IDs and statuses remain unchanged.
