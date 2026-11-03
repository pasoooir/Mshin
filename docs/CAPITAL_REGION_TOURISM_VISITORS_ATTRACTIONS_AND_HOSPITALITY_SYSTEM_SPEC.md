# Capital Region — Tourism, Visitors, Attractions & Hospitality System

**Status:** Design proposal only; not approved for V1 implementation.  
**Authority:** The V1 content catalog remains the sole authority for operational IDs and release status. This specification adds no operational IDs and changes no V1 status.

## 1. Purpose and principles

Design a visitor economy in which tourists are modeled visitors with finite time, budgets, origins, destinations and travel constraints—not a decorative crowd or unlimited source of income. Tourism emerges from accessible attractions, hospitality capacity, transport, public-realm quality, safety, affordability and service reliability.

- A visitor spawn is not a visit; arrival is not attraction entry; a booking is not a stay; spending intent is not collected revenue.
- Nominal venue capacity is not staffed, open, accessible or available capacity.
- Visitor flows use the authoritative spatial and mobility graph; no teleportation between attractions.
- Tourists are not residents, workers, households or permanent population.
- Spending is recognized only through validated transactions and reconciles with inventory, business accounts and municipal finance where applicable.
- Tourism demand cannot create unlimited money, jobs, goods, beds or transport capacity.
- No numeric visitor rates, attraction scores, stay lengths, prices, capacities, conversion rates, travel speeds or satisfaction weights are guessed; all remain TBD.
- Decorative visitors, billboards, landmarks and VFX cannot create tourism demand or economic effects.
- Unmodeled visitor segments, origins, attractions and behaviors are labeled Not modeled.

## 2. Visitor segments and lifecycle

Potential visitor segments are design candidates, not approved content: day visitors, overnight leisure visitors, business/conference visitors, event visitors and interregional travelers. Each segment requires an explicit reason for travel, origin, trip duration, budget model, party composition, mobility/accessibility needs and behavior profile. Do not create demographic assumptions without a defined gameplay need.

A visitor or travel-party lifecycle may include: potential, trip planned, route selected, traveling, arrived, itinerary active, visiting/staying, departing and departed. Exceptional states include canceled, delayed, stranded, refused entry, booking canceled or trip abandoned.

Keep party-level and individual counts consistent. If a party is the simulation unit, do not multiply its members into independent demand, bookings or spending. Arrival/departure updates visitor presence exactly once. Visitor presence is time-bounded and does not alter resident population totals.

## 3. Origins, destinations and attraction catalog

Attractions are typed destination records, not merely decorative buildings. Candidate types may include cultural heritage, museums, parks, waterfront/public realm, entertainment, sports/events, retail districts, landmarks and guided experiences. Each requires catalog approval before operational use.

An attraction definition records stable catalog identity/version; location footprint, entrances and accessible paths; opening calendar and admission/booking rules; nominal, staffed, safe and accessible capacity as separate measures; service requirements, operating costs and staffing; supported visitor segments; dwell-time model only when approved; accessibility, safety and closure conditions; dependencies on utilities, roads, public realm and maintenance; and evidence-backed visual asset/provenance references.

A visual landmark does not automatically provide an interactive attraction. A park may be public realm rather than a ticketed venue. Avoid double-counting one physical place as multiple attractions unless distinct zones, capacity and services are modeled.

## 4. Tourism appeal and destination choice

Destination choice must be explainable and based on authoritative inputs such as attraction availability, accessibility, travel cost/time, opening state, price, safety, service quality, crowding and visitor preferences where modeled.

Do not use an opaque single attraction rating. Display component measures and data coverage. No arbitrary appeal score or hidden random multiplier. Weather, seasonality, events, reputation, marketing and external travel trends are candidate factors only if their source systems and time behavior are explicitly defined.

A destination can be unavailable because it is closed, full, inaccessible, unsafe, disconnected or lacking required services. An unavailable destination must not continue to attract completed visits or revenue. Forecast interest is not confirmed demand or attendance.

## 5. Itineraries, trip planning and visitor time

A trip plan contains origin, intended destinations, sequence, travel legs, expected dwell intervals, opening windows, budget and constraints. Itinerary generation must use valid paths and avoid impossible schedules. A visitor cannot be simultaneously present at multiple destinations.

Travel time is a forecast until the visitor reaches the destination. Congestion, blocked roads, mobility modes, accessibility constraints, service interruptions and venue queues may alter arrival or cause itinerary changes only if those systems are modeled.

Visitors have finite time and budget. Unspent budget is not city revenue. A canceled or abandoned trip cannot produce completed-visit rewards. If itinerary planning is abstracted, the abstraction must still preserve time, route, capacity and accounting invariants.

## 6. Mobility and visitor access

Visitor mobility integrates with the approved road/access graph and any approved transport modes. Walking, private vehicle, taxi, bus, rail, bicycle or tour shuttle are candidates; none is activated merely by appearing in this list.

For each enabled mode, define network/route eligibility and graph version; capacity, accessibility and operating schedule; travel-time and cost model; transfer/waiting and last-mile behavior; vehicle/crew/fuel requirements where applicable; disruption and reroute behavior; and emissions/noise effects only if authoritative environmental systems support them.

Public transport remains subject to its existing Deferred status. This specification does not approve buses, stations, passenger terminals, bus lanes or new mobility IDs. Freight and passenger movement remain distinct, even when sharing road infrastructure.

## 7. Hospitality: accommodation and lodging

Hotels, hostels, serviced apartments, campsites and other lodging are candidate venue families requiring approval. A lodging venue distinguishes nominal room/bed inventory; available, reserved, occupied, out-of-service and inaccessible inventory; staffed/operational capacity; check-in/check-out windows; booking/cancellation policy; service quality and maintenance state; utilities, supplies and staffing prerequisites; operating cost; and transaction settlement.

A room reservation does not mean occupancy; occupancy begins only at validated check-in. A room cannot be booked by two parties for overlapping intervals. Check-out releases capacity exactly once. Closed, unstaffed or disconnected lodging cannot sell stays.

No room count, occupancy target, nightly price, staffing ratio, housekeeping cycle or service cost is assumed. All numeric parameters remain TBD.

## 8. Visitor spending and local business economy

Potential spend categories include lodging, food, retail, admissions, local transport, entertainment and services. A transaction records visitor/party, merchant, item/service, quantity, unit price, discounts, fees/taxes where approved, payment state, time, refund/dispute state and ledger reference.

Distinguish visitor budget, purchase intent, accepted order, goods/service delivered, gross transaction, merchant net proceeds, fees/taxes, refund/dispute and recognized revenue under the approved accounting basis.

Physical goods require available inventory and delivery/consumption rules. Service purchases require open capacity, staffing and service delivery. Spending cannot occur at a closed venue or exceed visitor funds. Gross visitor spending is not automatically municipal revenue; only defined taxes, fees, leases or public-venue proceeds may flow to the municipality.

## 9. Events, seasonality and destination management

Events, festivals, conferences and temporary attractions are candidate content. Each event requires organizer, location, approved schedule, finite capacity, ticket/entry rules, staffing, safety plan, transport/access plan, utility/waste needs, operating budget, cancellation conditions and post-event reconciliation.

Seasonality and weather effects require authoritative calendar/weather models and evidence. No random surge should create impossible crowding, free revenue or overloaded services. Marketing campaigns, tourism boards, reputation systems and destination rankings are not assumed features; if approved later, their cost, reach, conversion, lag and uncertainty must be measurable.

## 10. Urban services, safety and carrying capacity

Tourism adds load to roads, sidewalks, sanitation, water, electricity, public spaces, healthcare, policing, emergency response and maintenance. Incremental demand is generated from actual visitor presence and approved consumption/service rules.

For each affected service, distinguish nominal, staffed, effective, accessible and delivered capacity; visitor demand; resident demand; unmet demand; response time; and service quality. Protect resident service access through an explicit allocation policy. Do not silently prioritize tourists over residents or vice versa.

Crowd safety, emergency access, venue evacuation, waste overflow, noise and environmental pressure require explicit models before affecting gameplay. If not modeled, show the limitation rather than fabricate a safety or sustainability score.

## 11. District effects and tourism equity

Report visitor arrivals, completed visits, overnight stays, spend, public costs, congestion and service pressure by district only where source data is reliable. Include denominators, coverage and time interval.

Tourism benefits and burdens may differ spatially: revenue can concentrate in one district while transport, waste, noise and maintenance costs occur elsewhere. Show public investment, municipal receipts, local merchant proceeds, resident access and service burden separately. Avoid treating visitor count as an unqualified city-success metric.

Any district incentive, visitor levy, tourism tax or revenue-sharing policy requires separate approval in the content catalog and municipal finance model.

## 12. Simulation phases and determinism

Proposed high-level phase order:
1. Update authoritative venue/attraction operating state.
2. Calculate accessible capacity and service availability.
3. Generate eligible trip demand from approved visitor sources.
4. Plan destinations and routes using a versioned graph.
5. Reserve tickets, rooms and transport capacity atomically.
6. Move visitors and process arrivals/departures.
7. Process queue/entry/stay and service delivery.
8. Validate spending and merchant settlement.
9. Update visitor presence, district load and service demand.
10. Produce forecasts and explainable tourism metrics for the next interval.

Exact phase boundaries, intervals and model choices remain TBD. Avoid same-tick feedback loops between appeal, arrivals, crowding, revenue and investment. An arrival can affect a later forecast, not retroactively change its own trip selection.

Persist party/trip IDs, itineraries, bookings, capacity reservations, check-in/out, venue state, transaction IDs, route graph versions, visitor presence and settlement references. Save/load and offline catch-up must not duplicate visits, occupancy, spending or service demand.

## 13. Mobile-first tourism management UX

Portrait-phone views:
- Tourism overview: current visitors, arrivals/departures, overnight stays, completed visits and data coverage.
- Attraction directory/map: open/closed/full/accessibility state, access route and service dependencies.
- Venue detail: capacity breakdown, staffing, operating cost, visits and dwell/queue only if modeled.
- Hospitality: rooms/beds by state, reservations, check-ins, occupancy and maintenance.
- Event control: schedule, capacity, staffing, access, safety readiness and cancellation.
- District impact: visitor activity, merchant proceeds, municipal receipts, public costs and service pressure.
- Visitor-flow overlay: routes and density only from actual visitor state; never decorative density.
- Forecast panel: assumptions, uncertainty, time horizon and unavailable data.

Use large touch targets, safe areas, accessible labels, clear units, localized currency/time, non-color-only states and concise explanations. Separate actual from forecast and booked from completed. UI filtering and camera changes must not change simulation state.

## 14. Visual asset and specialist plugin pipeline

Tourism requires professional editable 3D assets and coherent visual storytelling: attraction architecture, hotel exteriors/interiors where in scope, public realm, signage, visitor characters, luggage/props, event staging and transport interactions.

The pipeline must use specialist design and asset tools/plugins for concept exploration, editable modeling, material/UV authoring, rigging/animation, prefab assembly, optimization and review. A generated concept image alone is not an accepted runtime asset.

For each deliverable retain source project/editable layers, export settings, mesh/material/texture references, scale/pivot, LOD/collision, mobile shader constraints, animation states, prefab contract, provenance, license and content hash. Use only free assets with explicit commercial-use rights unless separately approved. No paid asset purchase is assumed.

Visitor character variation must be optimized for mobile through shared rigs/materials, instancing/batching where supported, deterministic animation selection and strict visibility/LOD rules. No polygon, texture, crowd, draw-call or memory budgets are guessed; measure on the agreed minimum device.

## 15. Performance, accessibility and privacy

Crowd simulation must be bounded and LOD-aware. Use aggregated cohorts or event-driven visitor agents if individual simulation is too expensive, but preserve correct counts, capacity, route and transaction outcomes. Do not simulate every visitor at full fidelity when off-screen.

Accessibility includes step-free route data where available, venue access status, clear UI labels and alternatives for touch interaction. Do not infer sensitive personal attributes. Visitor identity should be pseudonymous and limited to gameplay requirements; real-world tracking or personal data collection is unnecessary.

Performance budgets, device floor, active visitor cap, update frequency, persistence size and offline catch-up limits remain TBD until profiling.

## 16. Acceptance scenarios

1. A decorative landmark with no attraction definition generates no visits or revenue.
2. A closed attraction receives no completed visits.
3. A full venue refuses or queues new visitors under approved policy; capacity is never exceeded.
4. An inaccessible route does not produce a valid arrival for a visitor requiring that access.
5. A visitor party is counted once and does not inflate resident population.
6. A trip with insufficient time cannot complete an impossible itinerary.
7. Travel disruption changes ETA or route; it never teleports visitors.
8. A room reservation blocks overlapping bookings; cancellation releases capacity once.
9. Occupancy begins at check-in and ends at check-out.
10. Unstaffed lodging cannot sell operational stays.
11. A purchase at a closed merchant is rejected.
12. Goods sold to a visitor reconcile with inventory and settlement.
13. Gross visitor spending is not counted as municipal tax revenue without an approved tax rule.
14. Event capacity and safety readiness gate admission.
15. Visitor load contributes to modeled service demand only once.
16. Resident and visitor service demand remain separately measurable.
17. District benefits and public costs are shown with valid denominators.
18. Save/load with visitors en route and rooms reserved creates no duplicates.
19. Offline catch-up does not duplicate arrivals, stays or purchases.
20. Small-phone tourism controls remain usable and accessible.
21. Crowd LOD reduces rendering cost without changing authoritative visit counts.
22. Missing attraction/visitor data appears as Not modeled, not fabricated.

## 17. Unresolved decisions and implementation gate

Visitor segment and trip unit; approved attraction and lodging IDs; visitor origin/generation model; destination choice; itinerary and dwell-time model; ticketing and booking; room/bed inventory; merchant categories; spending/settlement; service-demand coefficients; public transport availability; events and seasonality; district reporting; accessibility data; privacy boundaries; crowd abstraction; device floor and performance budgets.

All rates, prices, capacities, time intervals, attraction weights, spending distributions, crowd caps and performance thresholds remain TBD. Before implementation, approve tourism scope and IDs in the catalog; define visitor/party accounting; connect attractions to authoritative spatial access; define booking and transaction state machines; reconcile lodging, inventory and finance; define resident-service protection; create professional editable assets with specialist tools/plugins; verify commercial licenses, provenance and hashes; conduct mobile usability, accessibility and real-device performance tests; obtain explicit approval to leave design phase.

**Evidence status:** Documentation only. No tourist agents, attraction operation, hotel booking, visitor spending, event attendance or tourism simulation is implemented or device-tested by this document. Existing V1 IDs and statuses remain unchanged.
