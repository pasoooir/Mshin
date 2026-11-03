# Capital Region — District Service Allocation, Resource Equity & Crisis Management

**Status:** Design proposal only; not approved for V1 implementation.  
**Authority:** V1 operational IDs and release status remain controlled exclusively by the content catalog. This specification adds no IDs and changes no status.  
**Design target:** A mobile-first city simulation in which limited municipal resources are allocated transparently, services reach districts through valid networks, and crises are handled through deterministic, explainable rules.

## 1. Mission and non-negotiable principles

The city operates with finite money, staff, vehicles, materials, storage, network throughput and time. The player must choose where to invest and how to respond when demand exceeds available resources.

The system must:
- allocate only resources that exist, are available, compatible and reachable;
- distinguish a budget appropriation from a committed, dispatched, delivered or consumed resource;
- distinguish district need from political priority and from operational feasibility;
- expose underserved districts instead of hiding them in citywide averages;
- protect critical life-safety functions without making every shortage an emergency;
- preserve fairness, deterministic outcomes, accounting and player agency;
- avoid free resources, instant response, teleporting crews and retroactive service;
- explain why a district did or did not receive a service.

No numeric priority, reserve, response-time target, severity threshold, budget percentage or resource quantity is assumed here. All remain TBD pending design approval and testing.

## 2. Districts, service areas and authoritative geography

Districts are reporting and policy boundaries, not automatic service catchments. A facility may serve across district borders only through a valid domain-specific network or access path.

Every allocation request must resolve:
- requesting entity and affected population/cohort;
- authoritative district/geographic cell at request time;
- service/resource type and compatible unit;
- origin, destination and valid route/network version where transport is required;
- demand quantity, deadline/urgency class and evidence source;
- eligibility, exclusions and service coverage state.

District boundaries, road graphs, utility graphs and facility catchments are separate concepts. A road connection does not imply pipe/cable connectivity; a utility connection does not imply vehicle access. A facility's visual radius is not proof of service reach.

Requests crossing district boundaries must have one stable owner and one accounting identity to prevent duplicate demand or double allocation.

## 3. Resource taxonomy and lifecycle

Candidate constrained resources include:
- municipal operating and capital funds;
- staff by role, qualification, shift and availability;
- service vehicles and specialized equipment;
- repair parts, construction materials, fuel and consumables;
- electricity, potable water, storage and network throughput;
- facility slots, treatment/processing capacity and logistics capacity;
- response time and crew-hours.

For each resource, define a canonical unit, owner, location, quality/compatibility class, availability interval, reservation policy and loss/waste rules.

Resource lifecycle:
1. **Forecasted** — expected, not available.
2. **Budgeted/authorized** — funding permission only.
3. **Procured/produced** — exists in inventory or account.
4. **Reserved** — exclusively held for a request.
5. **Dispatched/committed** — assigned to a task or route.
6. **Delivered/consumed** — transferred or used with evidence.
7. **Released/returned** — unused reservation or reusable asset returned.
8. **Lost/expired/damaged** — recorded with cause and accounting effect.

A resource cannot be in two exclusive reservations at once. Failed, canceled or interrupted tasks must release or account for resources exactly once. A dispatch event is not proof of delivery.

## 4. Allocation request and decision contract

Each request carries:
- immutable request ID and idempotency key;
- service/resource category and unit;
- quantity and allowed partial-fulfillment behavior;
- district and affected population/geographic scope;
- urgency/severity evidence and timestamp;
- eligibility and compatibility constraints;
- valid source/destination and route/network snapshot;
- deadline or service window, if modeled;
- estimated and committed cost;
- status, decision reason and rule-set version.

An allocation decision records:
- eligible requests considered;
- resources available at decision time;
- priority/fairness policy version;
- feasibility checks and rejected alternatives;
- assigned quantity, source, destination and route;
- expected completion and uncertainty, if supported;
- cost reservation and responsible budget;
- tie-break result and audit reference.

Never silently discard a request. It must be fulfilled, partially fulfilled, queued, deferred, rejected with reason, or canceled with an auditable cause.

## 5. Multi-objective priority and fairness

Allocation should not be a single opaque “highest priority wins” score. Use a documented policy with distinct stages:

1. **Safety and legal eligibility gate:** reject incompatible, unsafe or unauthorized assignments.
2. **Criticality class:** classify immediate threat, essential continuity, routine service or discretionary improvement only where a validated incident/service model supports it.
3. **Need and unmet-demand evidence:** quantify the supported shortfall and affected eligible population.
4. **Time sensitivity:** account for deadline, deterioration or queue aging only when modeled.
5. **Equity review:** identify repeated under-service and distributional imbalance across districts.
6. **Operational feasibility:** confirm resource compatibility, staffing, inventory, route, network and funding.
7. **Deterministic tie-break:** stable, documented ordering so replay yields identical outcomes.

Fairness is not identical quantities for every district. It is a transparent rule that considers eligible demand, severity, access disadvantage, historical unmet service and operational constraints. Do not use resident wealth, building value or district label as an implicit priority unless an explicit policy is approved and surfaced to the player.

Use protected minimum service or rotating priority only if the service model defines measurable units and the rule does not violate critical safety requirements. Such mechanisms remain proposals until tested.

## 6. District equity diagnostics

For each modeled service, report by district:
- eligible demand and population coverage;
- delivered, unmet, deferred and queued quantities;
- effective and accessible capacity;
- response/delivery delay where measured;
- facility, staffing, inventory, route/network and budget constraints;
- cumulative under-service over a defined historical window;
- data completeness and uncertainty.

Do not compare raw quantities across districts of different sizes without denominators and unit clarity. Publish both absolute unmet quantity and an appropriate per-eligible-unit indicator when the denominator is valid.

Equity diagnostics must distinguish:
- **need disparity:** different underlying demand;
- **access disparity:** different ability to reach capacity;
- **delivery disparity:** different fulfilled share;
- **reliability disparity:** different interruptions;
- **data disparity:** different measurement coverage.

Do not label a district unfairly treated solely because its raw service total is lower.

## 7. Municipal budget and resource governance

Separate:
- capital budget and committed CAPEX;
- operating budget and recurring OPEX;
- emergency reserve, if approved;
- restricted funds and service-specific allocations;
- procurement commitments and unpaid liabilities;
- actual cash/ledger balance.

A planned project is not an expense until its approved lifecycle event. A reserved budget is not spendable elsewhere. OPEX must be funded for the actual operating interval; a facility with no operating funds follows an explicit approved degraded/paused policy, never hidden free operation.

Budget allocation workflow:
1. forecast eligible service demand and existing commitments;
2. identify mandatory/critical obligations;
3. calculate available uncommitted funds and resource stocks;
4. compare district needs and expected outcomes;
5. reserve budget and resources atomically;
6. execute procurement, staffing or dispatch;
7. record actual delivery/consumption and reconcile variances;
8. release unused reservations and publish the closing ledger.

Every transfer, purchase, consumption, refund and write-off is idempotent and auditable. No negative balance, duplicate payment or resource creation is permitted unless a clearly defined financing mechanic is later approved.

## 8. Crisis and incident lifecycle

A crisis system must not create arbitrary disasters simply to make the city difficult. Incidents originate only from modeled hazards, failures or authored scenarios with explicit scope and rules.

Incident lifecycle:
1. **Detected** — authoritative trigger and evidence recorded.
2. **Validated** — duplicate/noise checks; severity and affected area established.
3. **Classified** — service impact, urgency and response capability identified.
4. **Prioritized** — policy version and decision rationale stored.
5. **Resourced** — compatible crews/materials/funds reserved.
6. **Dispatched** — route and ETA computed from current valid graph.
7. **On scene / work started** — arrival/work evidence recorded.
8. **Contained / restored** — service state changes only after acceptance conditions pass.
9. **Recovery / cleanup** — residual tasks, costs and displaced demand tracked.
10. **Closed / reviewed** — final outcome, unresolved impact and lessons recorded.

Incidents may be merged only under explicit correlation rules. One incident may spawn multiple tasks; one task may serve multiple related requests only if quantities and ownership reconcile. Reopening creates a linked event, not an overwrite of history.

## 9. Emergency dispatch and response operations

Dispatch eligibility requires all necessary conditions:
- available qualified crew and shift;
- compatible vehicle/equipment;
- required materials and safety prerequisites;
- valid route/access graph and reachable destination;
- operating base/facility and communications state if modeled;
- budget authorization under the approved emergency policy.

Dispatch selection must consider severity, capability match, route cost/time, crew fatigue/shift constraints if modeled, and the opportunity cost of removing a unit from its current coverage. Do not send the nearest unit if it is incapable or already committed.

ETA is a forecast, not arrival. Recalculate only on defined route/incident changes and preserve the prior estimate for audit. Blocked routes, damaged bridges, fuel/parts shortages and concurrent calls must be handled explicitly. No crew or vehicle teleports.

## 10. Essential service continuity and rationing

When supply is constrained, each utility/service needs its own safe allocation policy:
- electricity: only if generation/import, network and demand model are approved;
- potable water: quality, pressure, storage and delivery constraints must be represented before rationing is simulated;
- wastewater: avoid overflow/health consequences unless flow and consequence models are approved;
- waste: distinguish collection, transfer, processing and final disposal;
- healthcare/emergency: allocate only to modeled demand and qualified capacity;
- maintenance: prioritize risk and service criticality with traceable work orders.

A shortage policy must state protected uses, eligible users, allocation unit, minimum safe level (if known), rotation/queue rules, outage behavior and recovery. If safe minimums are unknown, do not invent rationing values or claim safety; keep the domain conceptual and numeric TBD.

## 11. Network failures, cascading impact and resilience

Model a cascade only through explicit dependency edges. Example: loss of a power node may reduce a dependent pump's effective operation; that may reduce downstream water delivery if the relevant graph and capacity rules exist. Do not automatically infer health, happiness, migration, fire spread or economic loss without a separate approved causal model.

For each dependency, record:
- upstream/downstream entities and typed edge;
- failure mode and affected service;
- fallback, storage or redundancy if modeled;
- detection/propagation phase;
- recovery prerequisites and restoration evidence.

Resilience options may include redundant routes, backup stock, reserve crews, storage, spare capacity and preventive maintenance. They carry CAPEX/OPEX and should be compared through transparent scenario forecasts, not guaranteed immunity.

## 12. Player command center and mobile UX

Portrait-first command center:
- **Incident queue:** severity, age, district, affected service, status and action.
- **District equity view:** demand/delivery/unmet and data coverage with non-color-only patterns.
- **Resource board:** available/reserved/committed stock, qualified staff and vehicles.
- **Budget panel:** available, committed, spent, recurring OPEX and reserve.
- **Dispatch view:** unit capability, route, ETA confidence and coverage impact.
- **Allocation explanation:** why this request received/was denied/queued resources.
- **Crisis timeline:** detection, decisions, dispatch, arrival, restoration and cost.
- **Forecast comparison:** consequences of alternative policies with assumptions and uncertainty.

Every critical action needs a confirmation/undo policy appropriate to its reversibility, a clear cost and affected scope. Do not put dense desktop tables on a phone; use progressive disclosure, readable cards, touch-safe controls, accessible patterns and localized text. A map overlay is diagnostic, not the authoritative source of connectivity.

## 13. Determinism, accounting, persistence and audit

Required invariants:
- one resource unit cannot be allocated twice;
- total delivered/consumed/returned/lost reconciles with acquired stock;
- request quantities reconcile across fulfilled/partial/unmet/deferred/canceled states;
- incident costs reconcile with municipal ledger;
- dispatch does not imply arrival or task completion;
- a closed incident cannot silently mutate historical records;
- replay of an interval produces identical decisions and ledger state;
- save/load preserves active incidents, reservations, crew assignments, queues and graph versions;
- route/network updates invalidate stale dispatch paths;
- all allocation decisions record policy and source-state versions.

Use atomic reservation/commit semantics or equivalent transactional guarantees. Every operation needs idempotency keys. On failure, rollback or explicit compensating events must prevent orphaned reservations and double consumption.

## 14. Anti-exploit and adversarial cases

- no duplicate request creation by repeated triggers;
- no resource duplication through save/load, offline catch-up or task cancellation;
- no infinite emergency reserve or free procurement;
- no district score boost by moving boundaries or deleting denominator data;
- no dispatch of a crew to multiple incidents;
- no ETA manipulation by using stale/shortened routes;
- no priority farming by repeatedly reopening incidents;
- no hidden penalty for a district whose service is Not modeled;
- no profitable loop from buying, transferring, refunding or consuming the same stock;
- no suppression of unresolved demand by closing an incident early;
- no free operation when budget is exhausted;
- no same-tick cascade that multiplies damage without bounded rules.

## 15. Acceptance scenarios

1. Two districts request the same scarce compatible stock: one reservation wins deterministically; no double allocation.
2. A request is partially fulfilled: fulfilled and remaining quantities reconcile.
3. An unstaffed facility has nominal capacity but receives no impossible assignment.
4. A district has high raw demand but a lower eligible population: diagnostics show valid denominators and do not mislabel it.
5. Two equally eligible requests tie: stable tie-break produces identical replay.
6. A repeatedly underserved district is surfaced by historical equity diagnostics.
7. A route is blocked after dispatch: reroute/failure follows explicit policy; no teleport.
8. Nearest crew is incompatible: dispatch selects a capable unit or reports no feasible unit.
9. A crew is already committed: it cannot be dispatched twice.
10. Incident is detected twice: correlation/idempotency prevents duplicate work.
11. Incident is contained but service restoration criteria fail: incident remains open/recovery.
12. Emergency funding is reserved: it cannot be spent by a routine project simultaneously.
13. Operating budget is exhausted: approved pause/degradation behavior and ledger are visible.
14. Utility outage affects only explicitly dependent nodes and services.
15. Save/load during active dispatch preserves crew, reservation, route version and incident stage.
16. Replay/offline catch-up creates no duplicate resource movement, expense or service delivery.
17. Cancel a task after reservation: unused resources release exactly once.
18. Inspect a district with missing telemetry: data coverage is shown; no false zero or bonus.
19. A service domain is Not modeled: it is not included in fairness or score aggregates.
20. Small supported phone viewport: command center remains usable and accessible.

## 16. Unresolved decisions and TBD register

District granularity and boundary versioning; V1 service IDs; resource taxonomy/units; priority classes; fairness objectives and lookback window; queue aging; emergency incident catalog; severity and dispatch rules; response capabilities; route cost/ETA model; budget/reserve policy; procurement lead times; staffing/shift abstraction; utility safe minimums; dependency/cascade scope; incident generation rates; mobile device floor; performance and persistence budgets.

All numeric quantities, weights, thresholds, service targets and timings remain TBD. Each decision requires rationale, owner, test method and explicit approval evidence.

## 17. Integration and implementation gate

Related specifications:
- [Citizen Needs, Satisfaction & City Feedback](CAPITAL_REGION_CITIZEN_NEEDS_SATISFACTION_AND_CITY_FEEDBACK_SPEC.md)
- [Essential City Services & Utilities Atlas](CAPITAL_REGION_ESSENTIAL_CITY_SERVICES_AND_UTILITIES_ATLAS.md)
- [Public Transport & Road Infrastructure Atlas](CAPITAL_REGION_PUBLIC_TRANSPORT_AND_ROAD_INFRASTRUCTURE_ATLAS.md)
- [Capital Region World Spatial Spec](CAPITAL_REGION_WORLD_SPATIAL_SPEC.md)
- [Population, Workforce & Municipal Economy](POPULATION_WORKFORCE_MUNICIPAL_ECONOMY.md)
- [Capital Region V1 Content Catalog](CAPITAL_REGION_V1_CONTENT_CATALOG.md)

Before implementation: approve the service/resource/incident IDs and V1 scope; define units, allocation and fairness rules; approve safe operational constraints; define transactional data and save contracts; implement deterministic tests; produce editable professional assets via specialist tools/plugins; verify commercial licenses/provenance/hashes; perform mobile UX and real-device profiling; obtain explicit approval to leave design phase.

**Evidence status:** Documentation only. No allocation engine, district policy, budget reservation, incident simulation, emergency dispatch, utility rationing or crisis gameplay is implemented or device-tested by this document. Existing catalog IDs and statuses remain unchanged.


## Municipal finance and budget-control integration

Financial authority and cash constraints are specified in [Capital Region Municipal Finance, Taxation, Budgeting & Governance](CAPITAL_REGION_MUNICIPAL_FINANCE_TAXATION_BUDGETING_AND_GOVERNANCE_SPEC.md). District requests may reserve only resources backed by valid appropriation and available inventory/cash under the approved policy. Emergency commitments, procurement, accepted deliveries, incident expenditure, recovery costs and released reservations must reconcile exactly once with municipal journals. A budget allocation is not payment; a commitment is not delivery; a dispatch is not restoration. Restricted funds and emergency reserves remain subject to their own authorization and cannot be spent twice. This integration adds no operational IDs, budget policy or crisis capability to V1.
