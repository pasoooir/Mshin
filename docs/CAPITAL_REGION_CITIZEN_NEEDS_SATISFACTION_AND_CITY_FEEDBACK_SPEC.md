# Capital Region — Citizen Needs, Satisfaction & City Feedback System

**Status:** Design proposal only; not approved for V1 implementation.  
**Authority:** The V1 content catalog remains the sole authority for operational IDs and release status. This document adds no IDs and changes no status.

## 1. Objective and principles

Translate validated population and world state into measurable needs, service delivery, unmet demand and explainable player feedback. Residents must not become happier merely because buildings, decorations, counters or animations were added.

Keep four concepts separate:
- **Need:** a modeled requirement of an eligible cohort/household.
- **Demand:** its measurable quantity in a defined geography and interval.
- **Delivery/access:** what can actually be provided, considering effective capacity, staffing, network, access, operating state and budget.
- **Outcome:** a validated consequence such as unmet demand or a scorecard metric.

Prefer one consistent household/cohort abstraction compatible with the approved population model. Household, resident and agent counts are not interchangeable units. A domain without authoritative simulation data is **Not modeled**, excluded from aggregate calculations and never silently assigned a positive or neutral value.

## 2. Candidate need domains

| Domain | Candidate observable inputs | Guardrail |
|---|---|---|
| Housing security | usable capacity, occupied households, vacancy | Capacity is not population; no automatic occupancy |
| Employment | eligible workforce, staffed slots, matching, commute access | Job slot is not a filled job |
| Education/skills | eligible learners, effective staffed seats, attendance/progression | Nominal seats are not delivered education |
| Utilities | approved population/workplace demand, network delivery/outages | No conversion until units and IDs are approved |
| Healthcare/emergency | approved demand events, facility/unit capacity and access | Do not invent patient or incident rates |
| Waste/sanitation | approved generated quantity, collection and processing | Visual vehicles are not completed service |
| Mobility/access | reachable destinations, valid routes, travel impedance | No unsupported universal service radius |
| Environment/public realm | measured, modeled indicators only | Decorative objects grant no unmodeled benefit |
| Municipal affordability | revenue, committed OPEX, available budget | No hidden free operation or double-counting |

Each domain needs an approved source, unit, interval, geographic scope and acceptance tests. If these are absent, mark it Not modeled.

## 3. Demand and delivery accounting

Before implementation, define a versioned contract for each approved need:
- stable need type ID from an approved catalog/system contract;
- eligible population scope and exclusions;
- explicit quantity unit and time basis;
- geographic scope and boundary rules;
- deterministic demand-conversion rule;
- separate nominal, effective and accessible capacity;
- delivered, unmet and explicitly deferred quantities;
- source-state version, interval key and rule version.

For compatible units and a common interval, enforce:

**Demand = delivered + unmet + explicitly deferred.**

If a domain uses queues or incompatible units, specify its own conservation contract. Never force unlike quantities into one equation or count a quantity twice.

Effective capacity is constrained by the domain's actual dependencies. Accessible capacity is the portion reachable by eligible demand. Whether constraints combine through a minimum, flow network, allocation or other rule is domain-specific and remains TBD.

## 4. Causal graph and simulation order

1. **Authoritative world state:** commissioned buildings, roads/networks, budgets, staff, inventory and operating state.
2. **Population/workforce:** approved household/cohort flows, occupancy, eligibility and job matching.
3. **Need generation:** convert eligible state into demand once per interval.
4. **Capacity/access:** calculate effective and accessible capacity from real dependencies.
5. **Allocation/delivery:** resolve assignment deterministically with documented priority and tie-breaking.
6. **Unmet demand/outcomes:** calculate shortfalls, queues and validated metrics.
7. **Satisfaction/score snapshots:** derive only from modeled indicators and preserve raw inputs/rule versions.
8. **Player feedback:** explain bottlenecks and present forecasts; UI never mutates authoritative state directly.

This ordering prevents satisfaction from generating demand that changes the same interval's satisfaction. Any future migration/attractiveness feedback must apply in a separately versioned later interval with explicit bounds and tests—not through a same-tick circular dependency.

## 5. Satisfaction is not an opaque happiness meter

Keep these signals separate:
- **Need fulfillment:** delivered versus demanded quantity where units are comparable.
- **Access:** whether eligible residents can reach a service.
- **Quality:** only when a validated quality measure exists.
- **Reliability:** outages or missed service only where modeled.
- **Affordability:** only if a household cost/income model is approved.
- **Trust/sentiment:** deferred unless observable inputs and a non-arbitrary model are defined.

A domain exposes a satisfaction signal only after its inputs, units, aggregation, missing-data behavior and cadence are documented. Do not claim psychological realism from coarse simulation; label outputs as simulation indicators, not individual emotional states.

## 6. City scorecard and aggregation

The scorecard consumes versioned domain indicators, never building counts. Each dimension publishes raw metric/unit/interval/scope, denominator and coverage, normalization function/version, weight/version, missing-data behavior, source systems, causal explanation and forecast uncertainty where applicable.

Rules:
- Exclude Not modeled dimensions and show the exclusion explicitly.
- Do not treat missing data as zero, full satisfaction or neutral without an approved policy.
- Prevent duplicate credit for indicators measuring the same outcome.
- Report the population/geography coverage represented by valid data.
- A high aggregate must not hide a severe critical-service shortfall; critical constraints remain separately visible.
- Construction, asset count, animation, VFX and decorative density never directly add points.
- Historical snapshots retain exact metric, normalization and weight versions.

Weights, thresholds, normalization curves and score cadence remain **TBD**.

## 7. Geographic fairness and allocation

Citywide averages can conceal underserved neighborhoods. For each modeled service, expose demand, delivery, unmet demand, eligible population, data coverage, accessible capacity, route constraints, staffing/outages and budget by its supported geographic unit.

Allocation policy must document priority classes, fairness objective, tie-breaking, queue aging and behavior under shortage. Do not silently prioritize the nearest or wealthiest cohort unless explicitly approved and reviewable. Do not claim equity metrics without modeled population and geography data.

## 8. Bottleneck diagnosis and player agency

Identify binding constraints in the causal chain, including insufficient nominal capacity, staff/inputs, disconnected networks, inaccessible routes, OPEX/budget, demand saturation and invalid/missing data. Multiple simultaneous constraints must remain visible.

Recommendations may compare build, upgrade, hire, repair, route improvement, operating funding or moderated expansion. Show estimated effect, CAPEX/OPEX, affected districts/cohorts, dependencies, assumptions, uncertainty and time-to-effect. Never promise an outcome dependent on an unmodeled system.

## 9. Feedback loops and exploit resistance

Migration, housing demand, workforce participation and attractiveness feedback are **not approved** here. Each proposed loop requires source/target state, delayed application interval, bounded rate, deterministic rounding, eligibility, ledger reconciliation, replay/time-skip/save-load tests and an observable UI explanation.

Safeguards:
- no satisfaction bonus from facility count or duplicate coverage;
- no demand reduction by deleting residents or invalidating denominators;
- no score gain by disabling a poorly performing domain;
- no free capacity from unstaffed, disconnected, unpowered or uncommissioned facilities;
- no duplicate demand/delivery on replay or offline catch-up;
- no rewriting historical snapshots after score formula changes;
- no same-tick circular migration/service/score feedback;
- validate values and document rounding/remainder handling.

## 10. Mobile-first experience

Portrait-phone surfaces:
- **City pulse:** compact trend, coverage and last-update snapshot.
- **Needs panel:** domain cards with demand, delivered, unmet and Not modeled states.
- **District view:** selectable heatmap with non-color-only patterns and readable legend.
- **Bottleneck card:** cause, evidence, affected scope and confidence.
- **Action comparison:** cost, expected effect, dependencies and time-to-effect.
- **Score breakdown:** raw metric, normalization/version and contribution—not just a gauge.
- **Forecast:** horizon, assumptions, uncertainty and unmodeled dependencies.

Overlays require timestamps/snapshot versions, accessible labels, large touch targets, localization-safe layout and small-screen behavior. Visuals must read authoritative snapshots; hiding an overlay cannot change simulation.

## 11. Data, persistence and determinism

Persist or reproducibly reconstruct authoritative cohort/occupancy state, demand rule versions and interval keys, deterministic delivery results, score snapshots with formula versions, approved queues/deferred demand and any approved feedback events with idempotency keys.

Do not persist a derived display value as a second source of truth. On load, validate schema/version and rebuild derived indicators where safe. Migrations must preserve ledger invariants and never grant population, service delivery or score.

## 12. Acceptance scenarios

1. Build a residence: capacity rises; residents and satisfaction do not jump.
2. Add residents through an approved flow: demand updates once in its defined phase.
3. Add an unstaffed facility: nominal capacity may rise; effective delivery does not falsely rise.
4. Disconnect a required network: only dependent service capacity changes.
5. Block an access route: accessible capacity and affected cohorts update deterministically.
6. Saturate a service: delivery + unmet + deferred reconciles under its contract.
7. Add a duplicate facility: no unconditional score bonus.
8. Disable a service domain: it cannot improve score merely by disappearing.
9. Create a local shortfall while citywide averages remain healthy: local diagnosis still surfaces it.
10. Change staffing or OPEX: capacity and municipal ledger reconcile.
11. Replay/offline catch-up: no duplicate demand, allocation, expense or score event.
12. Change score formula version: historical snapshots remain distinguishable.
13. Hide overlays/remove decorative VFX: simulation and score remain unchanged.
14. Save/load with queued demand: no lost or duplicated demand/delivery.
15. Run with partial coverage: Not modeled domains and coverage are explicit.
16. Forecast a facility: assumptions and unmodeled dependencies are visible.
17. Smallest supported phone viewport: diagnostics remain readable and operable.
18. Long-run simulation: no unbounded positive feedback or score inflation.

## 13. Unresolved decisions and TBD register

Population granularity; need taxonomy/IDs; demand units and interval; geographic resolution; allocation/fairness policy; capacity combination per domain; quality/reliability/affordability scope; migration feedback; score dimensions/normalization/weights/guardrails; confidence method; UI thresholds; persistence schema; device floor and performance budgets.

Every decision needs rationale, owner, test method and approval evidence. Numeric values remain TBD; no guessed coefficients enter production.

## 14. Integration and implementation gate

Related references:
- [Education, Research, Housing Growth & City Wellbeing Atlas](CAPITAL_REGION_EDUCATION_RESEARCH_HOUSING_AND_CITY_WELLBEING_ATLAS.md)
- [Essential City Services & Utilities Atlas](CAPITAL_REGION_ESSENTIAL_CITY_SERVICES_AND_UTILITIES_ATLAS.md)
- [Population, Workforce & Municipal Economy](POPULATION_WORKFORCE_MUNICIPAL_ECONOMY.md)
- [Capital Region V1 Content Catalog](CAPITAL_REGION_V1_CONTENT_CATALOG.md)

Before implementation: approve capabilities/IDs in the catalog; select coherent V1 scope; approve demand units, causal rules and score formulas; define data/save contracts; implement deterministic accounting/tests; create professional editable assets through specialist tools/plugins; verify commercial licenses, provenance and hashes; profile and QA on supported phones; obtain explicit approval to leave design phase.

**Evidence status:** Documentation only. This does not implement citizen simulation, satisfaction, score, service demand, migration or gameplay behavior. No mobile gameplay/device test or asset delivery is claimed. Existing catalog IDs/statuses remain unchanged.


## District allocation and fairness integration
The allocation and crisis policy is specified in [Capital Region District Resource Allocation & Crisis Management](CAPITAL_REGION_DISTRICT_RESOURCE_ALLOCATION_AND_CRISIS_MANAGEMENT_SPEC.md). Need/demand metrics feed allocation only through approved service contracts; allocation outcomes return as delivered, unmet, deferred or queued quantities with district, interval and policy-version traceability. Fairness diagnostics must use valid denominators and disclose data coverage. Historical under-service may inform a future policy only after explicit approval; it must not create an unbounded same-tick feedback loop or an automatic score bonus.


## Municipal affordability and fiscal feedback integration

The proposed financial model is documented in [Capital Region Municipal Finance, Taxation, Budgeting & Governance](CAPITAL_REGION_MUNICIPAL_FINANCE_TAXATION_BUDGETING_AND_GOVERNANCE_SPEC.md). Affordability indicators may be exposed only when authoritative household/business income, charges and cost data exist. Tax bills are not cash payments; service funding is not delivered service; budget changes do not instantly alter satisfaction. Fiscal pressure, affordability and service outcomes must retain separate raw measures, denominators, intervals and formula versions. No tax burden, sentiment, migration or score formula is approved by this cross-reference; unmodeled domains remain Not modeled.
