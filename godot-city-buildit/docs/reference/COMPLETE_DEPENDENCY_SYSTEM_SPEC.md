# Mshin — Complete Dependency & Prerequisite System Specification

**Snapshot:** 2026-11-14  
**Scope:** every manufactured item, raw factory output, building, construction stage, residential upgrade, service, regional chain, trade transaction and unlock gate.  
**Purpose:** make the whole city economy explainable, auditable and impossible to bypass accidentally.

## 1. Non-negotiable design rule

**Nothing appears for free. Every output and every state transition must have an explicit, inspectable cause.**

A dependency does not always mean a material ingredient. It can be:
- a recipe ingredient;
- a production source (factory, farm, service or building);
- a facility/slot and elapsed production time;
- a building blueprint bill of materials;
- a level, population, star, region, technology or quest unlock;
- land, road, utility, workforce or service coverage;
- currency, capacity or a permitted trade transaction.

Do not invent ingredients to make a recipe look realistic. If the reference game treats a factory material as a direct factory output, preserve that recipe truth and make its *source requirements* explicit (factory type, unlocked material, available slot, operating time, access/utility requirements adopted by Mshin). Do not falsely claim that Metal requires Iron Ore unless the chosen Mshin design and its source data explicitly define that chain.

## 2. Four separate dependency dimensions

Every definition must distinguish these dimensions. They must not be collapsed into one generic "locked" state.

| Dimension | Question | Examples |
|---|---|---|
| Recipe inputs | What is consumed to create one output? | Nails = 2 Metal |
| Source/facility | Where and by what process is it created? | Metal = Factory output; Nails = Building Supplies Store |
| Unlock/eligibility | What must be true before the action is available? | Mayor Level, store stars, population, region, technology |
| Operational prerequisites | What must remain available for the facility/building to operate? | road connection, electricity, water, workers, service capacity |

A product can have all four. A raw factory material may have no recipe inputs but still has a source/facility, unlock and operating prerequisites.

## 3. Dependency graph contract

Represent the economy as a directed, quantity-aware graph:
- Nodes: raw material, crafted item, by-product, building, service, region, unlock, currency, capacity and demand/plan.
- Edges: `consumes`, `produced_by`, `requires_building`, `unlocked_by`, `requires_utility`, `requires_road`, `requires_population`, `requires_region`, `requires_capacity`, `traded_through`.
- Every edge records its source, quantity/unit where relevant, verification status and scope (capital/region).
- Recipe quantities are per one output unit. Batch demand = output quantity × each input quantity.
- The graph must be acyclic for consumable recipes. Detect and reject cycles before a recipe can be enabled.
- Missing definitions, missing sources, zero/negative quantities, invalid units, unknown unlocks and unresolved recipe conflicts block production; they must never silently become free outputs.
- A product definition with no recipe is not craftable. A catalog tile is not proof of a valid recipe.
- No default/fallback supplier may be invented when a product has no verified supplier.

## 4. Complete production chain

### 4.1 Raw factory outputs
A factory output is a primary production node, not a free inventory grant:
- Requires an eligible factory type, an available production slot, an unlocked material, a valid factory/material allowlist, an operational building and elapsed production time.
- Output is created only when the slot completes and is collected, subject to City Storage capacity.
- If Mshin later adds extraction inputs (ore, crude oil, crops, etc.), these must be explicit source recipes with quantities and provenance; do not backfill them from assumptions.
- Industrial tier/slot count, pollution, land footprint, road access and any adopted power/water/workforce requirements must be separately represented.
- Regional materials must be tied to their actual regional source/facility and region inventory policy. They must not be selectable from a capital factory unless explicitly allowed.

### 4.2 Commercial crafted products
For every product:
- Exact output quantity (normally one), direct ingredient IDs and quantities.
- Producing store ID and store availability.
- Base duration, any store-star modifier and batch/queue rules.
- Mayor Level and other verified unlock gates.
- Input stock, currently reserved/consumed quantities, missing quantities and supplier routes.
- Provenance per field (recipe, duration, level, stars, value); a source attached to a row must not be treated as proof for every field.
- A crafted ingredient must recursively expand to its own recipe until raw factory outputs or an explicit non-craft source are reached.

### 4.3 Intermediate products and subassemblies
An intermediate item is a normal inventory product with its own recipe and supplier. Examples in the current catalog include Planks, Nails, Hammer, Flour Bag, Cream and Home Textiles.
- If an output consumes an intermediate item, the player may use stock already in City Storage.
- Only the missing quantity expands upstream.
- Repeated dependencies share one virtual stock ledger across the entire requested batch. The same stored item must never be counted twice.
- If several target products are requested together, calculate their combined input requirements before displaying deficits.

## 5. Buildings: placement, construction and operation are different gates

Every building definition must declare three independent contracts:

### A. Placement / unlock gate
- Mayor Level and verified population requirement.
- Region ownership and region-specific unlock.
- Currency affordability.
- Land/plot availability and expansion ownership.
- Valid footprint, zoning/type compatibility and road access.
- Any required preceding building, milestone, technology or quest.
- Exact reason for each failed condition must be displayed.

### B. Construction bill of materials (BOM)
- Explicit material IDs and quantities, currency cost, construction duration and any workforce/equipment requirements.
- Construction consumes or reserves the full BOM atomically when the player confirms, according to the selected construction design.
- A construction site must visibly list owned / required / missing for every input.
- No building may finish if its required BOM is incomplete.
- Legacy buildings with no BOM must be explicitly marked `legacy_no_material_bom` until migrated. Do not pretend their Simoleon-only cost is a complete materials system.
- Blueprint revisions require save migration and regression tests.

### C. Operational gate
- Road connectivity and entrance/access.
- Utility demand/capacity (power, water, sewage, waste) where applicable.
- Workforce/employment requirement, if adopted for that building.
- Service coverage and region-specific operating conditions.
- Operating costs, pollution and production capacity.
- A building can be placed/unlocked but not operational; show these states separately.

**Current code audit finding:** inspected `BuildManager.gd` building definitions primarily declare Simoleon `cost`, `build_time`, level/population and footprint; the general building placement path spends currency and checks road access. It does not expose a universal per-building construction material BOM. Residential upgrade goods are a separate, existing system. Therefore a universal material-based construction economy is a future implementation gap, not something already complete.

## 6. Residential plans and all upgrade stages

Residential progression must be modeled per building instance and per transition:
- `from_stage`, `to_stage`, plan ID and plan generation/version.
- Exact item IDs and quantities, reward data, plan state and expiry/refresh policy if used.
- Current City Storage, reserved stock, ready-to-collect stock, in-production stock and remaining shortage.
- Supplier building and exact route to obtain each missing item.
- Population gain, XP, currency and unlock effects only after the transition completes.
- Materials are consumed atomically; a failed upgrade consumes nothing.
- Each inventory unit is allocated at most once across all active residential plans and other accepted commitments.
- A plan refresh/transfer mechanic must define eligibility, cost, cooldown, limits and persistence; no hidden rerolls.

**Reference boundary:** EA's public guide confirms the contractor-plan/drag-to-supply interaction, but does not publish one fixed universal material table for all residential stages. Mshin's current six-stage template is a Mshin rule, not exact SCBI data. Preserve it until a deliberate, tested design migration replaces it.

## 7. City services and infrastructure dependencies

Services must have both construction prerequisites and operational/capacity effects. Model these separately:
- Power: plant source, capacity produced, city/building demand, coverage/network rules, fuel/operating inputs if applicable.
- Water: source, capacity, demand and distribution.
- Sewage: treatment capacity versus generated load.
- Waste: collection/treatment capacity versus generated waste.
- Fire, police and health: coverage, response/access and demand; coverage does not imply unlimited capacity.
- Roads/transport: connected network, entrance/exit connectivity, road class, lane capacity and traffic demand.
- Education, parks, recreation and other specializations: unlocks, coverage, capacity and their effect on happiness/population where implemented.
- A service shortage must have a visible measurable effect and a clear explanation. Do not silently grant full service coverage because a building exists somewhere on the map.

If a service building itself consumes a resource (fuel, power, supplies, workforce), define it as an operating recipe/maintenance requirement with a cadence and source. Do not invent consumption quantities before the design is sourced and approved.

## 8. Employment, population and demand feedback

- Residential population creates measurable demand for utilities, services, goods and transport.
- Commercial/industrial/service buildings create jobs only through an explicit employment definition.
- Workers must be allocated once; do not count the same resident as a worker at multiple buildings.
- If workforce is not yet simulated, mark employment as `not_simulated`; do not imply that a staffing model exists.
- Population growth must not bypass housing capacity, service constraints or the selected game rules.
- Demand calculations must use a consistent snapshot and must distinguish required, stored, reserved, in-production, ready-to-collect and deficit quantities.

## 9. Regional economy

Each region must define:
- Unlock requirement from the capital city.
- Region identity, land/plot access and local currency if used.
- Local factories, local raw outputs, local stores and recipes.
- Whether City Storage is shared or region-specific.
- Cross-region transport/trade rules, fees, capacity and travel time.
- Climate/terrain/road/utility constraints where relevant.
- Region-specific products cannot leak into the capital catalog without a defined cross-region route.

The five current Mshin regional materials (Coconut, Snowberry, Cactus Fruit, Herbs, Olives) are Mshin-specific entries in the inspected catalog; do not present them as the exact SCBI regional raw-material list. Reconcile each against the selected region reference before enabling its full chain.

## 10. Trade, cargo, rewards and external grants

Every inventory change must have a transaction cause:
- craft completion/collection;
- residential/building plan supply return, if explicitly defined;
- purchase/trade with price, quantity, fees and counterparty;
- cargo/ship order with required goods and reward;
- quest/achievement reward with explicit reward definition;
- scripted starter grant or tutorial grant, explicitly named and one-time.

Transactions must be atomic, capacity-safe, idempotent on save/load and recorded in a ledger. No offer may request an item that is impossible to unlock or source in the player's current progression. A reward may create an item without a recipe only if it is explicitly classified as a grant/reward source, never as ordinary production.

## 11. Player-facing transparency contract

Every product/building/upgrade/service panel must answer:
1. What exactly will be created, upgraded or operated?
2. What must I have, and how many?
3. How many do I currently own?
4. How many are already reserved, being produced or ready to collect?
5. How many are missing?
6. Where can each missing input be obtained?
7. Is that supplier built, unlocked, connected, operational and available?
8. What is the complete upstream chain down to raw sources?
9. What is the estimated time and what assumptions affect it?
10. What is blocking the action right now?

Use clear states: `READY`, `MISSING MATERIALS`, `PRODUCING`, `READY TO COLLECT`, `SUPPLIER NOT BUILT`, `SUPPLIER LOCKED`, `NO ROAD ACCESS`, `UTILITY SHORTAGE`, `STORAGE FULL`, `RECIPE UNVERIFIED`, `SOURCE UNDEFINED`, `CONSTRUCTION BOM MISSING`.

The UI must show direct inputs first and offer an expandable complete dependency tree. Never hide an upstream dependency behind a generic "not enough materials" message. Distinguish a recipe lock from an inventory shortage.

## 12. Shared allocation and planning algorithm

For a requested output batch:
1. Validate item definition, recipe provenance, unlock state, source and cycle-free graph.
2. Clone one shared virtual inventory ledger from City Storage.
3. Subtract existing reservations and commitments according to deterministic priority.
4. Satisfy the target item from remaining stock first.
5. Expand only the remaining deficit through its direct recipe/source.
6. Aggregate repeated inputs across sibling branches before calculating shortage.
7. Continue until reaching raw sources or explicitly defined non-craft sources.
8. Report supplier/building/road/utility/unlock blockers at each terminal node.
9. Estimate time using actual parallel factory slots and each store's queue/slot availability. If a schedule cannot be computed reliably, label it approximate or unavailable; never show a false exact ETA.
10. Starting a job revalidates the snapshot and atomically consumes/reserves the full direct input set. If any check fails, consume nothing.

The same allocation engine must be used by the production panel, City Needs overview, residential plan panel, construction panel, trade eligibility and any future procurement assistant. Do not implement separate, contradictory shortage calculations in HUD scripts.

## 13. Data quality and provenance

Each recipe, unlock, cost, time, star gate and source rule must carry:
- source URL/name;
- source type: official EA, community reference, Mshin design decision or internal test;
- source revision/access date;
- field-level confidence: verified, cross-checked, disputed, unknown;
- region/version applicability;
- reviewer/change note.

Rules:
- Official EA sources establish official game behaviour where documented.
- Community databases are secondary evidence for detailed numeric values and may conflict or lag updates.
- User-approved Mshin rules may intentionally differ from SCBI; label them as Mshin design decisions.
- Unknown is a valid state. Never replace it with a guessed value.
- A conflict disables production/transition until reconciled or explicitly accepted as a documented Mshin variant.

## 14. Validation and regression gates

A complete dependency system is not accepted until automated tests cover:

### Recipe graph
- every craftable product has a valid source/store, positive duration and non-empty positive inputs;
- every input ID resolves to a known item or explicit external source;
- all crafted dependencies resolve recursively;
- no cycles, dangling IDs, negative quantities or implicit free output;
- disputed/unverified recipe cannot start;
- raw materials have a valid factory source and explicit production conditions.

### Inventory and allocation
- exact direct and recursive quantities;
- existing intermediate stock prevents unnecessary upstream production;
- repeated/shared inputs are aggregated without double-counting;
- multiple homes/jobs cannot claim the same stock;
- reserved, producing and ready goods are not double-counted;
- start/upgrade/trade operations are atomic and storage-capacity safe.

### Buildings and services
- no placement when unlock, population, region, land, currency or road requirements fail;
- no construction completion with incomplete BOM;
- no operation when mandatory utility/workforce/road conditions fail;
- service capacity and coverage are bounded and recalculated after building changes;
- all blockers are surfaced with actionable reasons.

### Progression and persistence
- all level gates and store-star gates tested at boundary levels;
- all region boundaries tested;
- save/load preserves plans, jobs, reservations, BOM consumption and transaction ledger;
- migrations cover any change to existing save schemas or six-stage residential plans.

### UI
- mobile landscape displays direct inputs, stock/deficit, supplier and lock reason without clipping;
- expanded dependency tree remains readable for deep chains;
- each blocker links to the correct supplier/build/upgrade action;
- no product appears startable if any dependency is unresolved.

## 15. Current inspected baseline and known gaps

This section records code facts, not desired future behaviour:
- `ProductionManager.gd` currently defines raw factory materials, commercial recipes, store catalog entries and a six-stage Mshin residential fallback plan.
- The current recursive dependency text expands crafted ingredients, consumes a shared in-memory stock ledger and stops at raw materials, unverified recipes or cycles.
- `CityDemandManager.gd` aggregates residential upgrade demand and allocates stored/ready/producing goods across homes so the same item is not shown as available to multiple homes.
- `BuildManager.gd` definitions contain level/population/currency/footprint/build-time and service metadata; the general placement path checks currency and road access. A universal material BOM and universal operational utility/workforce gate are not yet present.
- `StorageManager.gd` provides inventory counts and atomic has/remove helpers; any future reservation model must be integrated centrally, not duplicated in UI.
- The dependency audit already notes approximate ETA limitations: shared sibling queues are not fully scheduled and store-star reductions are not applied to the displayed chain estimate.
- The recipe catalog has 73 recipe definitions and one conflicting Tapestry catalog identity in the inspected snapshot. This is not proof that every possible current SCBI item is covered.
- Regional raw materials in Mshin are custom entries and need their own validated region chains.

## 16. Implementation sequence (do not skip gates)

1. **Catalog integrity:** validate every raw/crafted/catalog item, provenance, source and graph edge; produce a machine-readable audit.
2. **Unified dependency planner:** one inventory-aware, cycle-safe planner for direct/recursive requirements and blockers.
3. **All-level unlock rules:** centralize level, star, population, region, quest, building and technology gates.
4. **Building BOM:** define sourced/approved material requirements for each building type and construction transition; migrate legacy cost-only definitions explicitly.
5. **Operational dependencies:** connect roads, power, water, sewage, waste, workforce and service coverage to building operation where the selected design requires them.
6. **City-wide demand:** aggregate residential, construction, service maintenance, trade and production commitments without double allocation.
7. **UI transparency:** unify product, construction, residential, service and city overview dependency panels.
8. **Progression simulation:** test a fresh empty city through every level boundary, all stores, every region and save/load.
9. **Continuous reference review:** record user feedback, community source changes and balance findings as evidence-backed change proposals; never silently overwrite recipes.

A slice is complete only when its data, runtime validation, regression tests, player-facing explanation and tracker evidence all agree.
