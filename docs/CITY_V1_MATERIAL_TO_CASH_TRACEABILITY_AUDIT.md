# MSHIN — V1 Material-to-Cash Traceability Audit

- Audit date: 2026-11-03
- Repository: `pasoooir/Mshin`
- Branch: `docs/city-master-game-design`
- Status: design traceability audit only; **not implementation authorization or V1 approval**.
- Scope: existing V1 item/recipe IDs, catalog producer/consumer/storage entries, fleet status, workforce/economy dependencies and municipal finance/market proposal boundaries.
- Numeric quantities, prices, capacities, durations, rates, time intervals and performance budgets remain **TBD**.

## 1. Executive finding

**The V1 material-to-cash chain is not implementation-ready.** The documents contain a useful item and recipe vocabulary, but they do not yet define one closed, calibrated and approved end-to-end chain from a legitimate raw-material source through production, storage, transport, accepted consumption and reconciled municipal/business cash.

The audit does not add IDs, promote statuses, choose numeric values, define a new source of raw materials, or activate the proposal-only market/finance systems. Section 46 remains NOT READY.

## 2. Canonical authority and status boundary

| Domain | Canonical authority | Audit rule |
|---|---|---|
| Building/infrastructure identity and V1 status | `CAPITAL_REGION_V1_CONTENT_CATALOG.md` | No other document may add or promote an operational building or vehicle. |
| Item identity, base unit and recipe transformations | `CAPITAL_REGION_V1_ITEM_RECIPE_REGISTRY.md` | No market alias, implicit unit conversion or undocumented recipe. |
| Terrain, parcels, frontage, access and road graph | `CAPITAL_REGION_WORLD_SPATIAL_SPEC.md` plus map decision register | Geometry/proximity is not authoritative access or a freight route. |
| Trip, vehicle, dispatch and freight custody | `VEHICLE_FLEET_FREIGHT_TRAFFIC_SPEC.md` | Dispatch/ETA/visual animation is not arrival or delivery. |
| Population, workforce and municipal economy | `POPULATION_WORKFORCE_MUNICIPAL_ECONOMY.md` | Nominal capacity is not occupancy, staffing, employment, income or demand. |
| Tax, accounting, treasury and budget | `CAPITAL_REGION_MUNICIPAL_FINANCE_TAXATION_BUDGETING_AND_GOVERNANCE_SPEC.md` | Proposal only; no V1 tax, account mapping, opening balance or ledger implementation is approved. |
| Orders, market, settlement and interregional trade | `CAPITAL_REGION_MARKET_TRADE_SUPPLY_CHAIN_AND_INTERREGIONAL_COMMERCE_SPEC.md` | Proposal only; it cannot create tradable status, demand, buyers, money or freight capability. |

### 2.1 Relevant existing statuses — preserved

**Buildings**
- `IND-FACTORY-BASIC`: V1-Required.
- `COM-WORKSHOP-BASIC`: V1-Required.
- `LOG-WAREHOUSE-STARTER`: V1-Required.
- `TRADE-DEPOT`: V1-Support.
- `LOG-FREIGHT-TERMINAL`: Candidate.

**Items**
- V1-Required: `RAW-METAL`, `RAW-WOOD`, `MAT-PLANK`, `MAT-METAL-PART`, `MAT-CEMENT`, `GOODS-TOOLS`, `WASTE-WATER`.
- V1-Support: `WASTE-SOLID`.
- Candidate: `RAW-CHEMICAL`, `RAW-MINERAL`, `MAT-GLASS`, `GOODS-HARDWARE`, `GOODS-FURNITURE`, `GOODS-FOOD`, `RECYCLED-MATERIAL`.

**Recipes**
- V1-Required: `REC-RAW-METAL-01`, `REC-RAW-WOOD-01`, `REC-PLANK-01`, `REC-METAL-PART-01`, `REC-TOOLS-01`.
- Candidate: `REC-CEMENT-01`, `REC-HARDWARE-01`, `REC-GLASS-01`, `REC-RECYCLE-01`.

**Consumers**
- Existing registry entries: `CONS-BUILD-FOUNDATION`, `CONS-BUILD-UPGRADE`, `CONS-TRADE-NPC`, `CONS-POPULATION`, `CONS-UTILITY-PLANT`.
- These consumer labels do not independently approve the underlying construction-material, NPC-trade, household-goods or utility-fuel behavior. In particular, `CONS-TRADE-NPC` and `CONS-POPULATION` are not proof that an NPC buyer or item-level household demand is approved.

**Vehicles**
- `VEH-DELIVERY-VAN`, `VEH-WASTE-TRUCK`, `VEH-FIRE-ENGINE`, `VEH-POLICE-CAR`, `VEH-AMBULANCE`: V1-Support only.
- `VEH-HEAVY-TRUCK` and `VEH-CONSTRUCTION-TRUCK`: Candidate.
- `VEH-BUS`: Deferred.
- V1-Support status is not a blanket activation of dispatch, freight routes or commercial delivery.

No status is changed by this audit.

## 3. Material dependency matrix

| Chain stage | Existing canonical reference | Current traceability | Finding |
|---|---|---|---|
| Raw source → `RAW-WOOD` | `REC-RAW-WOOD-01` / `IND-FACTORY-BASIC` | Factory outputs the item; the actual source, extraction/abstraction rule, ownership, cost and replenishment are unspecified. | **Blocker — raw source missing.** |
| Raw source → `RAW-METAL` | `REC-RAW-METAL-01` / `IND-FACTORY-BASIC` | Same gap; “Operating resources TBD” is not a source contract. | **Blocker — raw source missing.** |
| `RAW-WOOD` → `MAT-PLANK` | `REC-PLANK-01` / `COM-WORKSHOP-BASIC` | Item and recipe IDs exist; quantity ratio, duration, workforce, utility, cost and output capacity are TBD. | Partial; not executable/calibrated. |
| `RAW-METAL` → `MAT-METAL-PART` | `REC-METAL-PART-01` / `COM-WORKSHOP-BASIC` | Item and recipe IDs exist; quantity ratio, duration, workforce, utility, cost and output capacity are TBD. | Partial; not executable/calibrated. |
| `MAT-PLANK` + `MAT-METAL-PART` → `GOODS-TOOLS` | `REC-TOOLS-01` / `COM-WORKSHOP-BASIC` | Input identities are named; input quantities, batch rules, duration, staffing, utilities, cost and output quantity are TBD. | Partial; not executable/calibrated. |
| Production output → storage | `LOG-WAREHOUSE-STARTER` | Warehouse is V1-Required; no approved storage profile, capacity, item compatibility, slot policy or reservation limits are finalized. | Partial; capacity contract missing. |
| Storage → freight pickup | `VEH-DELIVERY-VAN` | Vehicle is V1-Support; route graph, site access, payload, assignment, crew, loading throughput and operational activation are not approved. | **Blocked; do not assume freight is active.** |
| Freight → destination receipt | Fleet and market specs | Custody, dispatch, ETA, arrival, inspection, accepted quantity and unloading are conceptually separated; no approved V1 shipment state/schema or route graph is demonstrated. | **Blocked; design proposal only.** |
| Delivered goods → consumer | `CONS-BUILD-UPGRADE` | `GOODS-TOOLS` is named, but tier-material list, construction/upgrade eligibility and atomic consumption/refund rules are incomplete. | Partial; consumer contract unresolved. |
| Construction foundation | `CONS-BUILD-FOUNDATION` | Requires `MAT-CEMENT` (V1-Required), but its only listed producer `REC-CEMENT-01` is Candidate. | **Catalog/registry coverage conflict: required item has no Required producer recipe.** |
| Goods → NPC sale | `CONS-TRADE-NPC` / `TRADE-DEPOT` | Trade depot is V1-Support; NPC demand, budget, pricing, sale eligibility and settlement are proposal-only. | **Not approved for V1 activation.** |
| Household consumption | `CONS-POPULATION` | `GOODS-FOOD` is Candidate; item-level demand/stock consumption is not approved. | **Not an active V1 sink.** |
| Cash and ledger | Municipal finance spec | Finance document is proposal-only; currency, chart of accounts, opening balance, accounting basis, tax/fee types and approved V1 ledger are unresolved. | **Blocker — no approved monetary authority.** |

### 3.1 Candidate starter-chain assessment

The closest existing Required-only transformation chain to an upgrade consumer is:

`RAW-WOOD` → `MAT-PLANK` → `GOODS-TOOLS` → `CONS-BUILD-UPGRADE`

A parallel material branch is:

`RAW-METAL` → `MAT-METAL-PART` ↗

This is a **documented dependency sketch, not a complete playable chain**. It remains blocked by the undefined operating inputs behind the two raw-item factory recipes, uncalibrated recipes, workforce/utility/cost profiles, warehouse capacity/reservations, incomplete upgrade material contract, save/offline semantics and lack of an approved finance ledger. Separately, the Required item `MAT-CEMENT` is currently produced only by Candidate `REC-CEMENT-01`, so the foundation consumer is not covered by a Required recipe. This is a catalog/registry dependency mismatch requiring an explicit owner decision; do not silently promote the recipe or demote the item. No NPC trade or household item consumption is authorized.

## 3.2 Producer-status and raw-input coverage defects

The registry contains two precise blockers that must not be hidden by the broad “raw source missing” label:

1. `RAW-METAL` and `RAW-WOOD` are both V1-Required items and their listed Required recipes (`REC-RAW-METAL-01`, `REC-RAW-WOOD-01`) list only **“Operating resources TBD”** as inputs. Their names describe raw materials, but the registry does not identify the actual resource/source, replenishment rule, ownership, cost basis or whether these inputs are consumables, utilities or a budgeted abstract source. The producer recipe exists by ID; its input contract is incomplete.
2. `MAT-CEMENT` is explicitly **V1-Required**, while its only listed producer `REC-CEMENT-01` is **Candidate** and requires `RAW-MINERAL` (also Candidate) plus operating resources TBD. Meanwhile `CONS-BUILD-FOUNDATION` names `MAT-CEMENT` as a required construction input. This is a Required-item / Candidate-producer coverage conflict. It must be resolved by project-owner decision in the canonical catalog/registry; this audit does not change either status.

Required follow-up evidence: producer coverage for every Required item; exact source/operating-input semantics; approved source ownership and bounded replenishment; and a Required-only recipe path for each Required consumer. A listed item or consumer alone is not proof of an executable end-to-end chain.

## 4. Conservation, ownership and accounting invariants

The following are mandatory acceptance invariants, not a claim that they are implemented.

### 4.1 Item conservation

For each canonical item, unit, owner and location, reconcile:

`Opening usable stock + accepted receipts + validated production outputs + returns in`
`=`
`Closing usable stock + validated consumption + accepted dispatch/transfer out + explicit loss/spoilage + returns out`

The reconciliation must separately represent work-in-progress and transformations. Recipe inputs are consumed exactly once; outputs/by-products are created exactly once. A transformation may change item count but may not silently create economic value.

Inventory state must preserve the registry states: Available, Reserved-for-production, Reserved-for-construction, Reserved-for-trade, In-transit and Blocked-output. The sum of owned quantity across all states must reconcile to the authoritative quantity. Reservations change availability, not ownership. Custody transfer must have one explicit transition; the same cargo cannot be available at origin and destination simultaneously.

### 4.2 Reservation and capacity

- Source stock and destination capacity are validated before dispatch.
- Competing commands serialize or one fails deterministically.
- Reserve/release/consume/produce/transfer/list/delist/sell operations are idempotent.
- Full output storage blocks production completion safely; completed output is never dropped.
- Full destination, cancellation, partial delivery, rejection, return and process death release or retain each reservation exactly once.
- A purchase order, quote, listing, dispatch or ETA does not create inventory or prove delivery.

### 4.3 Vehicle and trip custody

- A trip requires real origin/destination identities, compatible vehicle, capacity, crew if required, accessible route and route graph version.
- Loading, departure, arrival, inspection, acceptance, unloading and closure are distinct events.
- Visual vehicles and animation do not mutate inventory.
- Dispatch is not delivery; arrival is not acceptance; accepted delivery is not payment settlement.
- Failure, route closure, reroute and offline recovery must preserve cargo ownership and prevent teleportation or duplication.

### 4.4 Money and ledger

If/when a V1 finance subset is explicitly approved:
- Budget authority, commitment, reservation, invoice/obligation, payment, cash receipt and posted ledger event remain distinct.
- Every monetary change has currency, source event, owner/account mapping, effective interval, reference and idempotency key.
- Each posted journal balances debits and credits per currency if double-entry is selected.
- Receivable-to-cash settlement does not count the same revenue twice.
- Gross sales, freight, fees, approved taxes, refunds, returns and net settlement remain separately traceable.
- Purchase order does not create stock; accepted receipt changes stock; payment does not itself prove accepted delivery.
- Reversals use compensating entries; history is not silently overwritten.
- No automatic money creation, unlimited NPC budget or circular arbitrage.

No chart of accounts, monetary values or accounting basis is selected here.

## 5. Missing cross-domain contracts

| Contract | Required decision/evidence | Current state |
|---|---|---|
| Raw-material origin | Resource/source identity, renewable/finite policy, ownership, extraction or abstract replenishment, cost and map location/access | TBD |
| Recipe execution | Exact quantities/units, duration, operating cost, utility/workforce profiles, batch and cancellation semantics | TBD |
| Storage | Capacity, per-item limits, compatibility, reservation ownership, overflow and migration | TBD |
| Workforce | Job slots, skills, shift, wage/cost profile, commute access and deterministic assignment | TBD |
| Utility dependency | Approved demand unit, supply topology, operational state and outage behavior | TBD |
| Construction consumer | Required material list, quantity, project reservation, progress, cancellation/refund and completion semantics | TBD |
| Freight activation | Approved vehicle subset, road compatibility, graph version, payload, loading/unloading, crew and shipment recovery | TBD |
| Destination receipt | Inspection, accepted/rejected/partial quantities, custody transfer, returns and inventory posting | TBD |
| Finance authority | Currency, accounting depth, accounts, opening balance, approved income/cost types and cash-shortfall behavior | TBD |
| Save/offline | Schema versions, deterministic tick phases, process-death recovery, idempotency and time manipulation defense | TBD |

## 6. Tick ordering and replay contract to resolve

A coherent future implementation must define one authoritative phase order across the domain owners. The market proposal suggests production completion → inventory reconciliation → demand/order generation → price snapshot → atomic reservation → picking/dispatch → shipment movement/delivery/inspection → consumption/settlement/ledger → next-interval forecasts.

This sequence is **not approved** and must be reconciled with the production registry, fleet simulation clock, workforce/economy intervals and municipal finance recognition rules before implementation. No subsystem may independently advance the same transaction or apply a second completion during offline catch-up.

Required replay evidence:
1. same initial save + same command/clock sequence produces identical stock, trip and ledger state;
2. replaying any command/event ID twice has one effect;
3. crash at every transaction boundary recovers without lost or duplicated stock/cash;
4. clock rollback/forward does not create production, tax, wages or shipment progress;
5. graph/schema migration preserves in-flight custody and reservations or fails safely;
6. long-run simulation reconciles all item and money balances.

## 7. Section-46 acceptance evidence still required

1. Approve one map and an actual raw-source model.
2. Select a single Required-only material chain and complete all units/quantities/costs/workforce/utility/storage/consumer contracts.
3. Resolve the `GOODS-TOOLS` upgrade consumer and project material requirements without relying on Candidate cement.
4. Decide whether freight is part of the initial approved loop; do not treat V1-Support vehicle status as activation.
5. Approve a bounded finance subset and ledger/cash model, or explicitly define a non-monetary first slice with no fake cash claims.
6. Define save schema, tick order, crash recovery and offline replay.
7. Provide deterministic conservation/reconciliation tests and mobile acceptance evidence.
8. Obtain explicit project-owner approval to leave the section-46 design gate.

Until then, no new production, trade, freight, household goods, utility graph or finance gameplay should be coded. Safe work remains limited to documentation, audits, and regression protection for already-existing behavior.

## 8. Sources reviewed

- `CAPITAL_REGION_V1_ITEM_RECIPE_REGISTRY.md`
- `CAPITAL_REGION_V1_CONTENT_CATALOG.md`
- `POPULATION_WORKFORCE_MUNICIPAL_ECONOMY.md`
- `VEHICLE_FLEET_FREIGHT_TRAFFIC_SPEC.md`
- `CAPITAL_REGION_MARKET_TRADE_SUPPLY_CHAIN_AND_INTERREGIONAL_COMMERCE_SPEC.md`
- `CAPITAL_REGION_MUNICIPAL_FINANCE_TAXATION_BUDGETING_AND_GOVERNANCE_SPEC.md`
- `CAPITAL_REGION_MAP_LAYOUT_DECISION_REGISTER.md`
- `CITY_DESIGN_PACKAGE_READINESS_AND_TRACEABILITY_AUDIT.md`
- `CITY_GAME_DESIGN_MASTER.md` sections 46, 47, 48 and 69

**Conclusion:** the dependency chain is now explicitly mapped, but the V1 material-to-cash loop remains incomplete, uncalibrated and unapproved. This audit closes no implementation gate and changes no game behavior.
