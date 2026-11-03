# Sims City — Gameplay Systems Specification

## 1. World and time
- World map owns terrain, water, buildable parcels, district boundaries and a stable seed.
- Time controller supports pause and configurable speed multipliers.
- Simulation uses deterministic ticks; day/night and seasons consume the same authoritative clock.
- Districts expose population, land value, employment, traffic, pollution, service coverage and happiness as derived metrics.

## 2. Road construction
- Tool states: idle → choose start → preview → validate → confirm → committed/cancelled.
- Preview shows snapped geometry, affected parcels, construction cost and warnings.
- Validation checks terrain slope, water, obstacles, overlap, endpoint connectivity and available funds.
- Road deletion checks dependent access/routes and requires a safe confirmation when it would isolate buildings.
- Road changes emit graph invalidation events and update route caches.

## 3. Zoning and buildings
- Zoning describes allowed use and density; buildings are separate entities with explicit footprints.
- Building definitions are data-driven: cost, build time, footprint, capacity, utility demand, workforce, pollution, operating cost and upgrade rules.
- Lifecycle: planned → under construction → operational → paused/abandoned → demolished.
- Building growth depends on demand, access, services, land value, taxes and environmental quality.
- Demolition refunds/penalties and salvage are explicit rules, not hidden side effects.

## 4. Citizens and households
- Household is the primary residential/economic grouping; citizen records represent individual needs and schedules.
- Citizens have home, optional job/school, income, education, health, needs and mobility preferences.
- Daily schedule creates home/work/school/shopping/leisure trips.
- Behavior is state-driven (at home, commuting, working, shopping, leisure, service-seeking).
- Near agents animate and pathfind; distant agents update statistical demand and commute counts.
- Visible NPC count never equals authoritative population count by assumption.

## 5. Economy and business
- City treasury is a double-entry-style ledger of categorized inflows/outflows (implementation may use balanced journal entries).
- Tax rates affect disposable income, business viability and demand with bounded, testable response curves.
- Businesses track inventory, production capacity, input goods, labor, operating cost, demand and delivery needs.
- Supply chain disruption reduces production/sales and can generate visible warnings and missions.
- Budget UI shows current balance, recurring income, recurring expense, debt and forecast assumptions.

## 6. Municipal services
Each service has facility location, coverage, staff/capacity, operating budget and response time.
- Utilities: generation/source, distribution network, consumption and outage state.
- Waste: collection routes, truck capacity, processing and disposal.
- Police/fire/health: service area, dispatch, travel time, capacity and incident resolution.
- Education: seats, catchment, attendance and education progression.
- A service is not considered functional merely because its building is placed; its coverage/capacity must affect target entities.

## 7. Traffic and pedestrians
- Road graph has directed lane edges and legal junction movements.
- Route cost combines travel time, congestion, turn penalty, vehicle class and closures.
- Vehicle behavior: follow lane, maintain headway, stop/yield, turn, merge, park and reroute on incidents.
- Pedestrians use sidewalks and crossings; they do not walk through building footprints or unsafe road surfaces.
- Public transport adds stop/route/capacity layers over the same mobility graph.
- Traffic overlays reveal congestion causes and route bottlenecks.

## 8. Driving integration
- Reuse Mshin vehicle dynamics, damage, touch/gyro input and audio after explicit city-road adapter work.
- Player vehicle route follows lane centerlines and obeys city collision/junction rules.
- Input contexts are mutually exclusive: city camera/build tools vs driving controls.
- Vehicle damage, fuel/energy and mission state persist according to city rules.
- Exiting the vehicle returns control to city mode at a valid pedestrian spawn location.

## 9. Mission system
- Mission definition includes id, type, prerequisites, start/end conditions, time limit, reward, failure conditions and city effect.
- Mission effects are domain commands; UI completion cannot directly grant rewards.
- Mission examples: deliver stock, take a citizen to clinic, respond to a fire, patrol a district, transport tourists, complete a legal race event.
- Acceptance verifies the relevant city value changes and remains changed after save/load.

## 10. Weather, environment and incidents
- Weather states are seeded/time-bounded and affect only declared systems: visibility, grip, demand, energy use, tourism and incident probability.
- Disasters/major incidents are later-scope features and must be recoverable with player decisions.
- Day/night changes lighting, building windows, traffic volume and business schedules.

## 11. UI/UX interactions
- Every control dispatches a command or changes a real view state.
- Panels display authoritative values and last-update time.
- Tooltips explain formulas/causes for non-obvious metrics.
- Touch targets, keyboard focus, contrast, safe areas and responsive layouts are acceptance-tested.
