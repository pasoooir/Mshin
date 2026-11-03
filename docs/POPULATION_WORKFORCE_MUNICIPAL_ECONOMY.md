# MSHIN — Population, Workforce, Household & Municipal Economy Design
Version: 0.1.0-design | Status: Draft | Scope: Capital V1 foundation

## 1. Purpose
This specification connects residential growth to jobs, production, household consumption, municipal revenue and public-service costs. Population is not a decorative counter. Every population or employment change must have an explicit cause, capacity limit and ledger/simulation trace.

## 2. Simulation entities
### 2.1 Household cohort
A cohort is a group of households sharing a profile. Minimum fields:
- cohortId and residentialBuildingId;
- householdCount and residentCount;
- employment participation band;
- income band (not personal salary records);
- consumption profile ID;
- commute mode profile;
- satisfaction components;
- last simulation interval and schema version.

Cohorts are aggregated to protect performance. Individual citizen agents are optional presentation entities and do not own authoritative economic state.

### 2.2 Workplace
A workplace profile declares job slots by skill band, wage cost profile, shift/availability model, utility demand and production/service role. Filled jobs cannot exceed slots. A building with no required workforce must say so explicitly.

### 2.3 Municipal account
The city ledger records taxes/fees, service operating costs, maintenance, construction spending, grants/rewards (if approved), trade income and debt/credit only if that system is separately designed. No currency change occurs outside a ledger transaction.

## 3. Population lifecycle
Population states are potential capacity, occupied, temporarily unserved, migrating/relocating and inactive. A residence gains residents only through a declared occupancy rule, not simply because a model was placed. Occupancy is bounded by tier capacity and city progression. Demolition and relocation preview population loss, job/commute effects and demand changes.

## 4. Employment matching
Employment is matched between household cohort job seekers and workplace vacancies using deterministic rules:
1. Determine available labor supply by cohort and skill band.
2. Determine open slots by workplace and skill band.
3. Apply commute feasibility using road graph travel cost.
4. Match in a stable priority order (policy and fairness rules documented).
5. Record employed/unemployed counts and wage flow.
6. Recompute only when relevant inputs change or at a scheduled simulation interval.

Do not simulate a full pathfinding commute for every resident each frame. Use cohort-level estimates and sampled agents for visual traffic. Unfilled vacancies and unemployed cohorts must be visible in diagnostics.

## 5. Household income and consumption
Household profiles define income bands and consumption baskets. A consumption basket may include essential utilities, goods and services. Each basket entry declares quantity per interval, affordability behavior, substitution rules and satisfaction impact. If detailed goods consumption is deferred, V1 must use a transparent simplified demand model rather than pretend to simulate item-level purchases.

Household consumption must not directly destroy warehouse inventory unless the goods transaction is explicit and traceable. Household-level demand, citywide market demand and physical inventory are distinct concepts.

## 6. Municipal revenue and costs
Potential revenue categories: residential/commercial/industrial tax, service fees and approved trade-related fees. Potential costs: utility operations, emergency services, waste collection, road maintenance, public facilities, wages and construction projects. V1 may use a small subset but must identify every source and sink.

Budget calculation is interval-based and ledgered:
- opening balance;
- revenue by source;
- operating costs by service/building;
- maintenance;
- project spending;
- adjustments/rewards with explicit reason;
- closing balance.

The UI shows current balance, interval net flow and top contributors. Forecasts are estimates and visually distinguished from settled ledger entries.

## 7. Satisfaction model
Do not compress all citizen experience into one unexplained number. Maintain components such as housing access, utility reliability, emergency/service access, employment opportunity, traffic burden, environment and affordability. Overall satisfaction is a documented aggregation function with versioned weights. If any component is not simulated, it must be labeled unavailable or simplified rather than fabricated.

Satisfaction should respond with understandable delay and bounded rates. A brief outage must not instantly erase long-term progress; chronic deficits should have cumulative consequences and clear warnings.

## 8. Economic feedback loops
- Residential growth increases demand, traffic and service load.
- Employment capacity enables income and production.
- Production consumes inputs and operating resources.
- Household demand creates a market sink only when the relevant goods economy is active.
- Municipal revenue funds service operations and maintenance.
- Service quality and access influence residential attractiveness.
- Congestion raises travel time and can reduce effective labor/service reach.
- Expansion adds capacity and opportunity but also network and upkeep costs.

Each loop needs at least one counterbalance. Avoid positive feedback that grows population, income and revenue without corresponding infrastructure or cost.

## 9. Policies and player agency
Policies are explicit city-level modifiers with:
- unlock condition;
- cost/upkeep;
- affected cohorts/buildings;
- formula and cap;
- effective interval;
- preview of winners/losers;
- reversible or irreversible status;
- acceptance and exploit tests.

Do not introduce policies as unexplained percentage sliders. A policy must create a meaningful trade-off and be understandable on a phone screen.

## 10. Exploit and fairness safeguards
- No negative wages, costs or taxes.
- No duplicate revenue on replay.
- No population created by loading a save repeatedly.
- No free job slots or service capacity from visual-only assets.
- No circular NPC buy/sell arbitrage.
- Clamp and validate all configurable multipliers.
- Use deterministic rounding rules and carry fractional remainders where needed.
- Offline catch-up cannot apply a daily transaction twice.
- Time manipulation cannot generate extra tax or wages.

## 11. V1 simplification boundary
V1 requires households, occupancy capacity, a small set of workplace slots, employment matching at cohort level, municipal income/cost ledger, utility/service demand and satisfaction components. Detailed individual salaries, complex class stratification, full commodity retail simulation, education-based career progression and macroeconomic cycles are candidates/deferred.

## 12. Acceptance scenarios
1. Add a residence: potential capacity changes, occupied population does not jump without occupancy rule.
2. Add workplace: job slots appear; employment matching is bounded.
3. Remove road access: commute/service reach changes deterministically.
4. Pause a factory: jobs/output and operating costs follow declared policy.
5. Increase population: utility demand and service load update once.
6. Disable a service: budget cost and service coverage change consistently.
7. Replay same interval: identical closing ledger and cohort state.
8. Return from offline interval: no duplicate tax, wages or consumption.
9. Inspect city budget: every displayed number reconciles with ledger.
10. Run a long simulation: no unbounded population/economy growth.


## Essential municipal services and utility demand integration
The proposed utility/service architecture is detailed in [Capital Region Essential City Services & Utilities Atlas](CAPITAL_REGION_ESSENTIAL_CITY_SERVICES_AND_UTILITIES_ATLAS.md). Population, household and workplace demand may feed electricity, potable water, wastewater and waste only after explicit demand-conversion rules and approved service IDs exist. Healthcare/emergency demand must not be invented as arbitrary patient or incident counts. Service delivery, staffing, inventory, operating costs and unmet demand must reconcile with the municipal ledger and deterministic simulation phases. A new service may not silently change occupancy, productivity, health, happiness, tax or population; every causal effect needs an approved rule and acceptance test. All quantities remain TBD until evidence exists.


## Education, housing occupancy and city wellbeing integration
The detailed proposed model is specified in [Capital Region Education, Research, Housing Growth & City Wellbeing Atlas](CAPITAL_REGION_EDUCATION_RESEARCH_HOUSING_AND_CITY_WELLBEING_ATLAS.md). Residential capacity and occupied population are separate quantities: construction changes potential capacity, while occupancy changes only through an approved population flow. Population demand must feed only approved jobs, education, utilities, mobility and public-service systems. Education progression, skill changes and research adoption are time- and capacity-bounded; no instant graduation or productivity bonus is allowed. City score dimensions must trace to implemented raw metrics and exclude systems marked Not modeled. CAPEX, OPEX, staffing, access, effective capacity and unmet demand must reconcile with the municipal ledger. No new population, education or score formula is approved by this cross-reference.


## Citizen needs, service delivery and city feedback integration

The proposed cross-domain model is documented in [Capital Region Citizen Needs, Satisfaction & City Feedback System](CAPITAL_REGION_CITIZEN_NEEDS_SATISFACTION_AND_CITY_FEEDBACK_SPEC.md). Population/workforce state may generate service demand only through approved, unit-defined conversion rules. Capacity, staffing, network access, delivered/unmet demand and OPEX must reconcile with municipal ledgers. Satisfaction and scorecard indicators must trace to authoritative metrics and formula versions; Not modeled domains are excluded transparently. Migration/attractiveness feedback is not authorized by this reference and must not create same-tick circularity. No operational IDs, new V1 scope or numeric formula are approved here.
