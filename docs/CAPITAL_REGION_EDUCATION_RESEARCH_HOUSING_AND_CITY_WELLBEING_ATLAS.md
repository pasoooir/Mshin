# Capital Region — Education, Research, Housing Growth & City Wellbeing Atlas

**Status:** Design specification / proposed systems. No implementation authorization; no V1 status change.  
**Engine:** Cocos Creator 3.8.6 / TypeScript. **Target:** Android and iOS, mobile-first.  
**Authorities:** V1 content catalog, population/workforce/economy specification, spatial specification and essential city services atlas.

## 1. Mission and governing principle

Define a coherent long-term city model in which residential construction creates potential housing capacity; eligible population processes may fill that capacity; population creates demand for jobs, education, utilities, mobility, healthcare, safety and public services; education and research can improve skills and productive capacity over time; and municipal investment can improve service quality only when capacity, staffing, access, reliability and recurring finance support it.

**Growth is not automatically success.** A new house increases potential residential capacity, not instant population. Population growth is bounded by a documented household/cohort and migration model. A new facility can improve service access or effective capacity, but also consumes land, staff, supplies, utilities and recurring budget. Unbalanced expansion can lower wellbeing even while population and building count rise.

No hidden multiplier, arbitrary score bonus, instant education-to-productivity jump or unmodeled population penalty is allowed.

## 2. Scope and catalog authority

This atlas covers housing supply, occupancy, population growth, schools, vocational training, colleges, universities, research, skill progression, labor matching, public-service capacity, city wellbeing and score, balancing, telemetry, mobile UI and acceptance testing.

These are conceptual systems until the V1 catalog grants stable IDs and statuses. Do not infer V1 approval for new residential tiers, school/university/research buildings, housing-market simulation, migration simulation, learner cohorts, patents or new city-score mechanics. Existing approved residence/workplace IDs and their current rules remain authoritative. This document does not silently alter them.

## 3. Core causal model

The causal chain must be explicit and inspectable:

1. Construction creates a building asset after valid placement and approved cost/material/time rules.
2. Residential capacity is potential occupancy, not population.
3. Occupancy changes only through a defined household assignment, migration or household-formation event.
4. Population generates modeled demand for housing, employment, education, transport, utilities and public services.
5. Service supply is constrained by facility capacity, staffing, operating hours, inventory, network access and budget.
6. Service experience reflects delivered service versus demand and access—not building count or proximity alone.
7. Education progresses eligible cohorts over time when capacity, staff, access and attendance conditions are satisfied.
8. Skills affect labor eligibility or productivity only through declared matching rules and measurable output.
9. Research creates validated outputs only if funded, staffed, equipped and connected to an adoption path.
10. Economy and wellbeing respond through explicit, bounded causal links; placing a building grants no direct score bonus.

Every link needs an owner, units, update phase, failure behavior, ledger effect, save/load contract and test.

## 4. Housing supply, occupancy and population growth

### 4.1 Residential lifecycle
Use explicit states: planned → under construction → commissioned → available → partially occupied / occupied → under maintenance / unavailable → retired. A building under construction or not commissioned cannot house residents. Usable capacity can be reduced only by an approved condition/damage model.

### 4.2 Capacity is not population
A residential asset may expose nominal capacity, usable capacity, occupied capacity, vacant capacity, access/service connection state and construction lifecycle. Do not assign population at placement. A new home changes available housing supply; residents arrive only through an approved population process.

### 4.3 Household or cohort model
Choose one consistent abstraction before implementation:
- Cohort model: aggregate population by age/education/employment categories; or
- Household model: household units with size/type and aggregate attributes.

Do not mix incompatible granularities. Migration and household formation must define eligible vacant housing, affordability if modeled, job opportunity, commute feasibility, service accessibility, growth rates (TBD), deterministic allocation/tie-breaks, move-in/move-out timing and capacity limits.

If rent/affordability is not implemented, do not imply it affects migration. If migration is not implemented, new homes only increase vacant capacity.

### 4.4 Population accounting
Where modeled, reconcile closing population = opening population + arrivals + births − departures − deaths. If births/deaths are outside scope, omit them rather than inventing a residual. Prevent double counting across household, cohort and building occupancy records.

### 4.5 Land use and placement
Residential placement obeys approved zoning/placement, terrain, road access and service connection rules. Density, height, floor area, setbacks, noise, pollution and hazard constraints remain TBD unless modeled. Visual occupancy must match simulation state; lit windows and crowd props cannot imply more residents than recorded.

## 5. Education system architecture

### 5.1 Potential stages
Early-childhood care, primary, secondary, vocational/technical training, college/university, adult learning and reskilling are candidate categories only—not approved catalog IDs. Select the initial playable scope deliberately rather than adding every tier at once.

### 5.2 Facility operation and capacity
A school or training institution provides service only when commissioned, accessible, supplied where required, staffed by qualified personnel, open according to schedule and has usable capacity. Keep separate seat capacity, staffed capacity, enrolled learners, attendance, throughput/completions and unmet demand. Do not compress these into one education score.

### 5.3 Learner progression
A learner cohort records stage, size, eligibility, enrollment, attendance, progression and completion. Progression is time-based and capacity-bounded. No instant graduation when a school is built. Enrollment allocation is deterministic and prevents double enrollment. If age cohorts are not modeled, do not claim child-specific coverage; use an explicitly simplified eligible-population abstraction.

### 5.4 Access and quality
Education access depends on valid road/pedestrian reachability and available seats, not circular radius alone. Travel time appears only if modeled. Staff availability, reliability and learning outcomes can affect quality only where defined. Proximity is not service delivery.

## 6. Skills, workforce and employment matching

### 6.1 Skill model
Define a bounded taxonomy relevant to actual workplaces (categories TBD). Workplaces declare requirements only when production logic supports them. Skills change through completed education, training or work experience under explicit rules.

### 6.2 Matching
Employment matching may account for job slots, worker eligibility/skill, commute reachability, workplace operating state and labor availability. No worker occupies multiple jobs beyond the declared contract. Unfilled jobs and unemployed eligible workers remain observable. If detailed skill matching is not implemented, retain the existing simpler model and do not fabricate skill bonuses.

### 6.3 Productivity and wages
Education improves productive capacity only through a validated chain: training completion → skill state → eligible job match → measurable productivity/output effect. The effect is bounded and explainable, and balanced against training time, staff and operating costs. No automatic citywide productivity multiplier.

## 7. Universities and research ecosystem

### 7.1 Candidate institutions
Universities, applied-science institutes, technical colleges, laboratories and industry research centers are candidate concepts only, pending catalog approval.

### 7.2 Research inputs and outputs
Research requires explicit inputs: qualified researchers, staff time, operating budget, equipment, utilities, facilities and program state. Outputs are typed, versioned and traceable. Candidate output classes include validated process improvement, technology unlock, material efficiency, service optimization and training curriculum; each requires its own contract.

### 7.3 Transfer and adoption
A research result has no gameplay effect until adopted by an eligible city system/workplace through documented implementation cost, compatibility check, staff training and rollout time. Research does not magically raise all production or service scores. Track program state, consumed resources, milestones/evidence, validated output, eligible adopters, adoption cost/time and measured before/after outcome. Avoid a generic research-points currency unless conversion and spending rules are fully specified.

## 8. Public services: demand, capacity and quality

### 8.1 Supply versus demand
For each approved service, track demand, nominal capacity, effective capacity after staffing/utilities/operating state/inventory, accessible capacity after route constraints, delivered service, unmet demand, reliability/downtime and recurring cost/resource use. Empty seats, absent staff, utility outage or no valid route cannot count as full service.

### 8.2 Coverage and marginal benefit
Coverage derives from reachable capacity, not facility count or simple distance. If routing is not implemented, label access as approximate planning data and exclude it from authoritative score inputs. New facilities improve service only when they address unmet demand, access gaps or reliability. When supply already exceeds demand, another facility may yield little benefit while increasing OPEX and land use. No unconditional building bonus.

### 8.3 Dependencies
Education and healthcare need staff, utilities and access. Utilities need trained workers, parts and budget. More residents increase demand across services. Research improves efficiency only after validated adoption. Service shortfalls may affect attractiveness/migration only if that causal link is explicitly approved.

## 9. City wellbeing and score framework

### 9.1 Score is a diagnostic, not a magic number
Candidate dimensions: housing adequacy/affordability (if modeled), employment opportunity/job matching, education access/progression, healthcare/emergency/public-safety access, utility reliability, waste/environmental cleanliness, mobility/accessibility, fiscal sustainability, environmental quality/land-use balance and citizen wellbeing/satisfaction (only with a validated model).

A dimension not implemented is marked “Not modeled” and excluded from the aggregate—not assigned zero or a fabricated neutral value.

### 9.2 Normalization and aggregation
Every implemented dimension defines raw metric and units, target/acceptable range with evidence source, normalization function, weight/version, update cadence, missing-data behavior and confidence/coverage indicator. Do not choose weights or targets arbitrarily. Start with a transparent scorecard; calibrate weights through gameplay tests and explicit design approval. Evaluate weighted mean, geometric mean or bottleneck-aware aggregation with sensitivity analysis before selecting. Never combine incompatible scales without normalization.

### 9.3 Critical bottlenecks
A high average must not hide a severe modeled failure (for example, no safe water or emergency access) once those systems are approved. Define critical guardrails only with explicit rules and show the condition that triggered them. Never hide an unexplained penalty.

### 9.4 Explainability
Every score change records metric before/after, cause, affected population, source tick, score version and confidence. No random drift. Update only when inputs change or at documented evaluation cadence. Show positive and negative contributors, not only the headline score.

## 10. Growth and capacity balancing

### 10.1 Coupled growth
Residential expansion increases potential population; population raises demand for jobs, schools, utilities, waste, roads, healthcare and emergency services. If homes are built faster than jobs/services, vacancy may remain high or unmet demand may rise according to approved rules. If demand grows faster than capacity, service indicators and wellbeing may decline.

### 10.2 Capacity planning dashboard
Show current population and occupied/vacant housing; residential pipeline by lifecycle; job slots/employment/unfilled jobs; education seats/enrollment/unmet demand; utility and service demand versus effective capacity; road/access constraints; municipal income, OPEX, CAPEX and balance; projected capacity after committed construction; forecast horizon, confidence and assumptions. Forecasts are not guarantees.

### 10.3 Investment trade-offs
Every facility has capital cost, materials/construction time, land opportunity cost, recruitment/training, recurring wages, utilities, supplies, maintenance, access/traffic demand, expected service-capacity change and dependency/failure exposure. Placement preview shows known costs and modeled effects before confirmation. Unknowns are labeled TBD.

### 10.4 Phased expansion loop
1. Measure demand, effective capacity and unmet need.
2. Identify the binding bottleneck: housing, jobs, education, utility, road, budget or staff.
3. Compare build, upgrade, staffing, route and efficiency options.
4. Preview capital and recurring costs.
5. Commit only if financing and inputs are feasible.
6. Commission and verify.
7. Measure actual service and score contribution.
8. Reassess the next bottleneck.

This prevents “build everything” and facility-count strategies from dominating gameplay.

## 11. Municipal budget and fiscal sustainability

Separate capital expenditure (CAPEX) from operating expenditure (OPEX). Schools, hospitals, utilities, depots and emergency stations require staff, energy, supplies and maintenance. A facility is not a net benefit if the city cannot fund its operation.

Every ledger event has an idempotency key. Construction and recurring costs are distinct. Paused, under-construction, commissioned and unavailable facilities follow explicit billing rules. Subsidies and taxes are traceable. No facility generates income merely by existing unless a documented economic activity supports it. Forecasts and actuals are visually distinct. Debt, interest, taxation and affordability are optional systems requiring separate approval.

## 12. Mobile-first UI and player feedback

### 12.1 City overview
Compact scorecard: population/housing occupancy; jobs/workforce matching; education access/progression; key service reliability/access; municipal financial balance; city score/trend; top causes of improvement/decline.

### 12.2 Explainable recommendations
Recommendations identify bottleneck, evidence and possible interventions. Example: “Staffed school capacity is below reachable eligible demand; consider staffing, access or additional seats.” Do not say “build more schools” when the real constraint is staff, road access or budget.

### 12.3 Placement preview
Housing: construction cost, potential capacity, access/utilities, projected demand; explicitly state residents do not appear instantly.
Schools/facilities: nominal/effective capacity, staff needs, dependencies, CAPEX/OPEX, reachable demand and expected unmet-demand change only if forecast is reliable. Unknown effects show “Not modeled” or “TBD”.

### 12.4 Accessibility
One-handed touch, safe areas, readable typography, high-contrast indicators, text+icon+pattern redundancy and clear confirmation for costly actions. Never rely only on red/green.

## 13. Deterministic simulation and conceptual data contracts

Conceptual records—not a production schema:
- ResidentialAssetState: asset ID, nominal/usable capacity, occupancy, vacancy and lifecycle.
- PopulationCohort OR HouseholdAggregate: choose one granularity; count, eligibility, education/employment state.
- PopulationFlowEvent: arrivals/departures/formation, reason, tick and idempotency key.
- EducationFacilityState: institution, seats, staff, enrollment, attendance, operation and service area.
- LearnerCohort: stage, size, progression, attendance and completion.
- SkillProfile: category/version/level and provenance.
- WorkforceDemand: job slots, required skills and workplace status.
- ResearchProgram: inputs, staff, milestones, outputs and adoption state.
- ServiceCapacitySnapshot: demand, nominal/effective/accessible capacity, delivered/unmet and source tick.
- CityScoreSnapshot: version, dimension metrics, weights, exclusions, confidence and explanations.
- InvestmentProposal: CAPEX/OPEX, dependencies, forecast, assumptions and approval state.

Suggested deterministic phase order: committed construction/lifecycle → housing capacity → population flows → service demand → service capacity/allocation → education progression → workforce matching → production/economic ledger → research milestones/adoption → score snapshot → presentation. If another order is selected, document and test it. Avoid circular same-tick dependencies. Presentation consumes immutable snapshots and cannot mutate simulation state.

## 14. Exploit resistance and failure modes

- Placing a house cannot instantly create residents, taxes or labor.
- Placing a school cannot instantly educate residents or create skilled workers.
- Placing a university cannot instantly unlock technology.
- Duplicate facilities cannot grant duplicate coverage for the same finite demand.
- Service delivered cannot exceed effective capacity.
- Staff shortages, outages and road disconnection affect only dependent services.
- Paused/uncommissioned facilities cannot provide full service.
- Decorative assets, building count and unverified forecasts cannot raise score.
- Score weight changes require a score-version migration/recalculation policy.
- Replaying a tick cannot duplicate move-in, enrollment, graduation, employment, revenue or research output.

## 15. Professional asset and plugin pipeline

Candidate visual families: residential typologies, schools, vocational campus, university, research labs, libraries, learning/sports spaces, student mobility and public realm. None is automatically approved for V1.

Production assets require editable source, clean topology, UVs, PBR materials, scale/pivot convention, LODs, collision policy, Cocos prefab, state hooks, mobile compatibility, dependency manifest and automated validation. Use Blender and specialist procedural/geometry, retopology, UV, material, rigging, LOD and export plugins where appropriate. Retain editable source and record tool/plugin versions. Concept images or AI renders are reference only, not production assets. Free assets require commercial license, provenance, attribution review and per-file hash.

## 16. Acceptance matrix

| Area | Required evidence |
|---|---|
| Housing capacity | Building raises potential capacity only |
| Occupancy | Residents enter only through approved population flow |
| Population ledger | Opening + flows = closing; no duplicate events |
| Housing constraint | Occupancy never exceeds usable capacity |
| Service demand | Population change updates approved demand exactly once |
| School capacity | Enrollment cannot exceed effective staffed capacity |
| Education progression | No instant graduation; deterministic and bounded |
| Skills | Change only through validated education/training/work events |
| Employment | Matching respects slots, eligibility and access |
| Research | Outputs require inputs, staff, milestones and adoption |
| Public service | Benefit depends on delivered capacity and access |
| Budget | CAPEX/OPEX reconcile with ledger and lifecycle |
| City score | Every dimension traces to raw metric, version and cause |
| Missing systems | Not-modeled dimensions are excluded transparently |
| Bottleneck | Severe modeled shortfall is visible and explainable |
| Forecast | Assumptions, horizon and confidence are displayed |
| Persistence | Population, occupancy, education and score persist consistently |
| Determinism | Replay yields identical outcomes |
| Mobile | Placement preview, scorecard and diagnostics pass phone QA |
| Visual truth | Occupancy, staff and activity match simulation state |

### 16.1 Required scenario tests
1. Place a residence: capacity rises; population and tax do not jump.
2. Commission a home and trigger eligible population flow: occupancy rises once and stays within capacity.
3. Fill all homes: further arrivals are rejected/queued by documented rule.
4. Add homes without jobs/services: vacancy or unmet demand responds only through approved migration rules.
5. Add school seats without staff: effective capacity does not equal nominal capacity.
6. Add staff and route access: effective accessible capacity rises within constraints.
7. Fill school: additional learners remain unmet/queued, not silently enrolled.
8. Advance learner cohort: completion occurs only after defined duration/conditions.
9. Graduate cohort: workforce eligibility changes, but employment/productivity do not change without matching.
10. Build university: no research benefit until staffing, funding, program and milestone conditions pass.
11. Adopt validated research output: only the eligible target system changes.
12. Build duplicate facility in saturated district: no unconditional score bonus.
13. Expand housing faster than services: dashboard identifies bottleneck and budget exposure.
14. Add facility whose OPEX exceeds available budget: preview warns; operation follows approved funding policy.
15. Trigger utility outage: only dependent facilities lose effective capacity.
16. Change score version in test fixture: old/new snapshots remain distinguishable.
17. Replay interval: no duplicate migration, enrollment, graduation, payroll, research or tax.
18. Save/load during construction and education progression: no premature commissioning or duplicated cohort progress.

## 17. Unresolved decisions and numeric TBD

V1 education stages and facility IDs; population granularity; migration/household formation; births/deaths; rent/affordability/tax rules; residential capacity units; education eligibility/progression/time; skill taxonomy and workplace requirements; research scope/output/adoption; city score dimensions, normalization, weights, guardrails and cadence; satisfaction model; facility capacity/staffing/cost/wages/construction times/service ranges; forecast horizon/confidence; device floor and performance budgets.

All numeric values remain TBD until tested and approved. No guessed score weight or population rate enters production.

## 18. Implementation gate and evidence status

Before implementation: approve IDs/status in catalog; select minimum coherent V1 scope; define state/data contracts and units; approve population and score formulas; define economy/save migration; implement deterministic tests; produce professional editable assets with verified licenses; validate mobile UX and real-device performance.

**Current status:** documentation only. No population formula, education progression, research system, housing migration, city score, facility, asset or gameplay behavior has been implemented or device-tested by this document. Existing catalog statuses remain unchanged.
