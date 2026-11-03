# MSHIN — Capital Region V1 Master Content Catalog
Version: 0.1.0-design | Status: Draft for review, not implementation authorization
Engine: Cocos Creator 3.8.6 / TypeScript | Platforms: Android and iOS, mobile-first

> Original Mshin design. This catalog does not claim that SimCity BuildIt uses identical rules. Unknown numeric values remain TBD until simulation and playtesting.

## 1. Governance and data rules

### 1.1 Content status
| Status | Meaning |
|---|---|
| V1-Required | Required for a credible end-to-end Capital vertical slice |
| V1-Support | Supporting content required in compact form |
| Candidate | Consider after core loop is stable |
| Deferred | Explicitly outside first slice |
| Decoration | Visual-only; no hidden gameplay effect |

### 1.2 Source of truth
Every shipped content item requires a stable ID, schema version, localization keys, visual asset keys, footprint, placement rules, lifecycle, operational/economic contract, upgrade path, save migration rule, telemetry events and acceptance suite. IDs are immutable after release; display names are localized strings, never identifiers.

### 1.3 Units and unknowns
- Area is measured in grid cells; grid-to-world conversion is a single project-wide constant.
- Simulation time is measured in seconds and is independent of render frame rate.
- Currency uses typed wallet entries; regional currencies must never be silently mixed.
- Utility capacity, production, population, service and storage quantities must declare units.
- TBD is unknown, not zero. Do not replace TBD with invented balance values.

## 2. Capital V1 scope

| Family | Status | Purpose | Key dependencies |
|---|---|---|---|
| Road network and intersections | V1-Required | Access and route graph | Placement, traffic |
| Residential houses | V1-Required | Households, population, demand | Road, utilities, services |
| Basic materials factory | V1-Required | Raw/basic material production | Workforce, power, storage |
| Basic commercial workshop | V1-Required | Crafted goods | Recipes, inventory |
| Warehouse | V1-Required | Capacity-constrained inventory | Producers and consumers |
| Small power station | V1-Required | Electricity supply | Network, upkeep |
| Water pumping station | V1-Required | Water supply | Network, upkeep |
| Sewage treatment | V1-Required | Wastewater capacity | Water demand, network |
| Waste depot | V1-Support | Collection and temporary capacity | Fleet, road, capacity |
| Fire station | V1-Support | Emergency response | Route, fleet, staffing |
| Police post | V1-Support | Safety capacity | Route, staffing |
| Community clinic | V1-Support | Health capacity | Route, staffing |
| City hall | V1-Support | Budget and policy | Economy, population |
| Construction office | V1-Support | Project queue | Materials, time |
| Trade depot | V1-Support | Sell eligible surplus | Warehouse, market |
| Freight terminal | Candidate | Regional logistics | Fleet, route |
| Education | Candidate | Workforce quality | Population, budget |
| Parks/recreation | Candidate | Wellbeing and land value | Land, upkeep |
| Public transport | Deferred | Mobility capacity | Road graph, demand |
| Airport/port | Deferred | High-capacity trade | Regional network |
| Tourism/landmarks | Deferred | Visitor economy | Services, transport |
| Advanced research | Deferred | Technology progression | Education, economy |

Explicitly outside V1: multiplayer, clubs, player-to-player trading, premium currencies, monetization, loot boxes, time-skip purchases, advanced/futuristic economy, cross-region production, full weather simulation and catastrophic disasters. These require separate decisions and abuse/economy reviews.

## 3. Capital region assumptions
1. One starter map with a defined buildable boundary and expansion gates.
2. One authoritative road graph serves placement validation, service access and vehicle routing.
3. Buildings occupy explicit grid footprints and declare frontage/access requirements.
4. Service coverage depends on connectivity, capacity and operational state; proximity alone is insufficient.
5. Residential population is represented by household cohorts for simulation efficiency. Individual citizens may be visual agents only.
6. The starter region uses a deliberately restrained item set. Region-specific goods wait for the regional economy design.

## 4. Building catalog

### 4.1 Infrastructure and roads
| ID | Name | Status | Footprint | Contract |
|---|---|---|---|---|
| INF-ROAD-LOCAL | Local road segment | V1-Required | 1x1 segment | Adds graph edge; capacity and speed TBD |
| INF-ROAD-INTERSECTION | Intersection node | V1-Required | Graph node | Junction delay and legal turns |
| INF-ROAD-UPGRADED | Upgraded road | Candidate | 1x1 segment | Explicit capacity/upkeep delta |
| INF-ROAD-BRIDGE | Bridge | Deferred | Terrain-dependent | Crossing constraint and upkeep |

Roads are graph infrastructure, not conventional production buildings. They must support connectivity, path cost, congestion, construction blocking, emergency access and route invalidation.

### 4.2 Residential
| ID | Name | Status | Footprint | Access | Operational inputs/outputs |
|---|---|---|---|---|---|
| RES-HOUSE-STARTER | Starter house | V1-Required | 2x2 provisional | Frontage | Household capacity; utility and goods demand |
| RES-HOUSE-FAMILY | Family residence | V1-Required | 2x2 provisional | Frontage | Higher capacity and demand |
| RES-APARTMENT-LOW | Low-rise apartment | Candidate | 2x3 provisional | Frontage | Higher density and traffic |
| RES-APARTMENT-MID | Mid-rise apartment | Deferred | 3x3 provisional | Frontage | High density and service load |

Occupancy must be bounded by configured capacity and explicit rules. Visual height must never imply population without a data value. Household cohorts carry population, employment band, income band, consumption profile and satisfaction state; no personal data is required.

### 4.3 Industry and workshops
| ID | Name | Status | Footprint | Access | Contract |
|---|---|---|---|---|---|
| IND-FACTORY-BASIC | Basic materials factory | V1-Required | 2x2 provisional | Freight-capable frontage | Raw/basic production; time, workforce and operating costs |
| COM-WORKSHOP-BASIC | Basic workshop | V1-Required | 2x2 provisional | Freight-capable frontage | Converts inputs using recipe queue |
| IND-FACTORY-ADVANCED | Advanced factory | Candidate | 3x2 provisional | Freight frontage | Multi-input production and by-products |
| COM-WORKSHOP-ADVANCED | Advanced workshop | Deferred | 3x2 provisional | Freight frontage | Advanced recipes |

Production states: idle, queued, running, blocked-input, blocked-output, paused, disabled and upgrading. Queue state must survive process termination and offline progression.

### 4.4 Utilities and environmental services
| ID | Name | Status | Footprint | Contract |
|---|---|---|---|---|
| UTL-POWER-PLANT-SMALL | Small power station | V1-Required | 2x2 provisional | Supplies power capacity; incurs declared operating cost/input |
| UTL-WATER-PUMP | Water pumping station | V1-Required | 2x2 provisional | Supplies water capacity |
| UTL-SEWAGE-PLANT | Sewage treatment plant | V1-Required | 2x2 provisional | Processes wastewater capacity |
| ENV-WASTE-DEPOT | Waste collection depot | V1-Support | 2x2 provisional | Fleet collection and temporary capacity |
| ENV-RECYCLING-YARD | Recycling yard | Candidate | 2x3 provisional | Converts eligible waste into bounded recoverable inputs |

Coverage is a network/capacity problem, not a decorative radius. UI distinguishes disconnected, connected-but-under-capacity, supplied and degraded. Impacts and recovery time are shown before relocation or demolition.

### 4.5 Civic and emergency services
| ID | Name | Status | Footprint | Contract |
|---|---|---|---|---|
| SVC-FIRE-STATION-SMALL | Small fire station | V1-Support | 2x2 provisional | Response fleet and coverage |
| SVC-POLICE-POST | Police post | V1-Support | 2x2 provisional | Safety capacity |
| SVC-CLINIC | Community clinic | V1-Support | 2x2 provisional | Health capacity |
| GOV-CITY-HALL | City hall | V1-Support | 2x2 provisional | Budget and city policies |
| GOV-CONSTRUCTION-OFFICE | Construction office | V1-Support | 2x2 provisional | Construction queue and project state |

Service quality accounts for route time, capacity, staffing/operating state and simultaneous demand. A map radius may visualize an estimate but is not the authoritative service algorithm.

### 4.6 Storage and trade
| ID | Name | Status | Footprint | Contract |
|---|---|---|---|---|
| LOG-WAREHOUSE-STARTER | Starter warehouse | V1-Required | 2x2 provisional | Total/category capacity and reservations |
| TRADE-DEPOT | Trade depot | V1-Support | 2x2 provisional | Lists eligible inventory for sale |
| LOG-FREIGHT-TERMINAL | Freight terminal | Candidate | 3x2 provisional | Dispatch/receive regional shipments |

Storage defines total capacity, item limits, reserved stock, locked stock, queued-production reservations and overflow behavior. No item may disappear silently. Listings reserve inventory atomically.

## 5. Building Definition contract

The following TypeScript interface is the conceptual minimum. Production schemas must also validate references and migration compatibility.

```ts
type CatalogStatus =
  | "v1-required" | "v1-support" | "candidate"
  | "deferred" | "decoration";

interface BuildingDefinition {
  id: string;
  schemaVersion: number;
  status: CatalogStatus;
  family: string;
  localization: { nameKey: string; descriptionKey: string };
  visual: {
    prefabKey: string; iconKey: string; lodProfileKey: string;
    materialSetKey: string; animationSetKey?: string;
  };
  placement: {
    footprint: { width: number; height: number };
    rotationSteps: 2 | 4;
    requiresRoadAccess: boolean;
    frontageCells?: string[];
    terrainTags?: string[];
    forbiddenOverlapTags?: string[];
  };
  lifecycle: {
    unlockRuleId: string;
    constructionRecipeId?: string;
    constructionDurationSeconds?: number;
    upgradeTrackId?: string;
    demolitionPolicyId: string;
  };
  operation: {
    operatingMode: "passive" | "producer" | "consumer" | "service" | "network";
    inputRecipeIds?: string[];
    outputItemIds?: string[];
    serviceProfileId?: string;
    utilityDemandProfileId?: string;
    workforceProfileId?: string;
    storageProfileId?: string;
  };
  economy: {
    buildCostId: string; upkeepProfileId?: string; revenueProfileId?: string;
  };
  simulation: { tickGroup: string; offlinePolicyId: string; deterministic: true };
  save: { migrationPolicyId: string; defaultStateVersion: number };
  acceptanceSuiteId: string;
}
```

Schema validation rejects duplicate IDs, missing localization/assets, invalid footprints, negative capacities, unknown enum values, cyclic upgrade definitions and missing recipe references. Decoration definitions cannot contain production, service, population or economic modifiers.

## 6. Placement and lifecycle rules
1. Preview placement before charging currency or consuming materials.
2. Validate footprint, terrain, map boundary, overlap, frontage, network access and unlock rules.
3. Show exact blocking reason and a corrective action.
4. Preview consequences: service disconnection, lost capacity, traffic change, production interruption and demolition refund.
5. Require confirmation for destructive actions.
6. Apply placement as one atomic simulation command.
7. Persist command result and resulting entity state.
8. On load, reconcile references; missing definitions must fail safely.

## 7. Upgrade contract
Each tier defines functional delta (capacity/output/demand/coverage/resilience/efficiency), visual delta (silhouette/facade/roofline/props/light/material), economic delta (inputs/downtime/upkeep/payback), service and traffic deltas, unlocks, maximum tier, demolition behavior and save migration. A cosmetic tier is explicitly marked cosmeticOnly and cannot imply a hidden functional buff.

## 8. Release gates
- IDs are unique and immutable.
- Every V1 building has icon, preview, world asset and mobile LOD.
- Every operational building has state-transition tests.
- Producers/consumers have reservation and overflow tests.
- Service buildings have disconnected, capacity-limited and recovery tests.
- Localization and text-overflow checks pass.
- Minimum supported screen size and touch target checks pass.
- No placeholder art, fake counters or inert controls in a release candidate.
- Numeric balance values include source, rationale, version and simulation evidence.

## 9. Open decisions
Map dimensions/grid scale; Capital climate and resource deposits; final footprints after art blockout; utility topology (graph, cells or hybrid); household cohort and agent limits per device profile; whether construction requires workers, materials or both; sellable goods and NPC trade rules. Do not resolve these by inventing values.


---

## 10. Visual design and delivery references

The visual identity and tier presentation of Capital Region catalog entries are specified in:
- [Building Visual Progression Atlas](BUILDING_VISUAL_PROGRESSION_ATLAS.md): building-by-building architectural direction, required reference views, state visuals and mobile art handoff.
- [Capital Region Building Visual Matrix](CAPITAL_REGION_BUILDING_VISUAL_MATRIX.md): catalog ID coverage, operational class, visual identity, required facade/roof elements and delivery status.

These documents do not change catalog status, gameplay balance, provisional footprints or implementation authorization. All unknown numeric values remain TBD. Asset/model/prefab/device verification must be evidenced independently.


## 11. Road, transit and mobility infrastructure design references

The future-facing system design for road hierarchy, highways, bridges, intelligent intersections, bus lines, stops, terminals, public parking, transit corridors and network expansion is documented in [Capital Region Public Transport & Road Infrastructure Atlas](CAPITAL_REGION_PUBLIC_TRANSPORT_AND_ROAD_INFRASTRUCTURE_ATLAS.md).

This reference does not change the statuses in this catalog:
- `INF-ROAD-LOCAL` and `INF-ROAD-INTERSECTION` remain V1-Required.
- `INF-ROAD-UPGRADED` remains Candidate.
- `INF-ROAD-BRIDGE` remains Deferred.
- `VEH-BUS` and Public transport remain Deferred.
- `LOG-FREIGHT-TERMINAL` remains Candidate and is not a passenger terminal.
- Public parking, highway, transit stops/terminals, bus lanes and adaptive signal control have no approved operational catalog IDs yet.

Any move into implementation requires a catalog change with stable IDs, data contracts, lifecycle, economics, save migration and acceptance tests. All numeric values remain TBD until simulation/device evidence exists.


## Proposed essential services and utilities atlas — reference only
The detailed conceptual architecture for electricity, potable water, wastewater, solid waste, emergency response, healthcare, public safety and municipal maintenance is documented in [Capital Region Essential City Services & Utilities Atlas](CAPITAL_REGION_ESSENTIAL_CITY_SERVICES_AND_UTILITIES_ATLAS.md).

**Catalog protection:** this reference adds no operational IDs and changes no V1 status. Unless an item is already explicitly approved here, these services and their facility/asset families remain proposed conceptual scope, not V1-Required. In particular, do not infer approval for power generation, substations, water/sewer networks, waste facilities, fire stations, hospitals, police stations or maintenance depots from the atlas. Each proposed capability requires stable IDs, status, dependencies, economy, save/load and acceptance approval before implementation. Existing catalog entries and statuses remain authoritative; all numeric values remain TBD.


## Education, housing growth and city wellbeing design reference
The proposed education, research, residential occupancy and city wellbeing architecture is documented in [Capital Region Education, Research, Housing Growth & City Wellbeing Atlas](CAPITAL_REGION_EDUCATION_RESEARCH_HOUSING_AND_CITY_WELLBEING_ATLAS.md).

This reference does not add operational IDs or change V1 statuses. Schools, vocational institutions, universities, research facilities, new housing tiers, migration/housing-market mechanics and new city-score dimensions remain proposed until individually approved in this catalog. Existing residence/workplace entries and current rules remain authoritative. A placed home increases potential capacity only; it does not create residents. No score bonus is granted for building count. Numeric capacities, migration rates, score weights and targets remain TBD.


## Citizen needs, satisfaction and city feedback — design reference

The proposed causal model for resident needs, demand, effective/accessibile capacity, service delivery, unmet demand, satisfaction indicators and the city scorecard is documented in [Capital Region Citizen Needs, Satisfaction & City Feedback System](CAPITAL_REGION_CITIZEN_NEEDS_SATISFACTION_AND_CITY_FEEDBACK_SPEC.md).

This reference adds no operational IDs and changes no V1 status. It does not approve migration feedback, new service domains, satisfaction formulas or score weights. Building count, decorative density and visual effects grant no direct score. Domains without authoritative modeled data remain Not modeled and are excluded transparently. Existing catalog entries and statuses remain authoritative; all numeric values remain TBD.


## District resource allocation and crisis management — design reference

The proposed district-level allocation, fairness, municipal resource governance, emergency dispatch and crisis lifecycle are specified in [Capital Region District Resource Allocation & Crisis Management](CAPITAL_REGION_DISTRICT_RESOURCE_ALLOCATION_AND_CRISIS_MANAGEMENT_SPEC.md).

This reference creates no operational IDs and changes no V1 status. It does not approve new service types, incidents, emergency units, rationing policies or budget mechanics. Resources remain finite and auditable; allocation requires compatibility, availability, access, staffing and funding. Dispatch is not proof of arrival or restoration. Existing catalog entries/statuses remain authoritative and all quantities/thresholds remain TBD.


## Municipal finance, taxation, budgeting and governance — design reference

The proposed municipal finance, tax administration, treasury, budgeting, procurement finance, capital investment, debt/grant and policy-governance model is specified in [Capital Region Municipal Finance, Taxation, Budgeting & Governance](CAPITAL_REGION_MUNICIPAL_FINANCE_TAXATION_BUDGETING_AND_GOVERNANCE_SPEC.md).

This reference adds no operational IDs and changes no V1 status. It does not approve any tax type, fee, accounting basis, debt instrument, grant mechanism, budget policy or governance control for V1. Candidate features remain subject to explicit catalog approval; all numeric rates, amounts, periods and thresholds remain TBD.


## Market, trade, supply chain and interregional commerce — design reference

The proposed market, order/contract, pricing, inventory reservation, freight delivery, settlement and interregional commerce architecture is specified in [Capital Region Market, Trade, Supply Chain & Interregional Commerce](CAPITAL_REGION_MARKET_TRADE_SUPPLY_CHAIN_AND_INTERREGIONAL_COMMERCE_SPEC.md).

This reference adds no operational IDs and changes no V1 status. It does not approve new tradable goods, market venues, NPC buyers, dynamic pricing, tariffs, freight modes or regional trade routes. Existing item and vehicle registry entries/statuses remain authoritative; all quantities, prices, capacities and timing values remain TBD.
