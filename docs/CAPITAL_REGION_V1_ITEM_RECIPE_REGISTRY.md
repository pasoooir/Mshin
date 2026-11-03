# MSHIN — Capital Region V1 Item & Recipe Registry
Version: 0.1.0-design | Status: Draft, values uncalibrated
Scope: Capital starter economy

## 1. Purpose and invariants
This is the authoritative registry for item identity and transformations. Buildings reference these IDs; they must not invent ad-hoc item names or production logic.
- Item IDs are immutable; localized names are separate keys.
- Every item declares a base unit. Incompatible units cannot be compared.
- Recipes explicitly declare duration, input reservation, output capacity, workforce/utility demand and cancellation behavior.
- No recipe creates unbounded value from nothing. Outputs trace to inputs, operating cost, by-products or an explicitly budgeted source.
- TBD values remain unknown until simulation and playtesting.
- Simulation is deterministic; future online authority must not trust client completion timestamps.

## 2. Item taxonomy

| Item ID | Concept | Category | Unit | Status | Role |
|---|---|---|---|---|---|
| RAW-METAL | Metal | Raw | item | V1-Required | Factory output |
| RAW-WOOD | Timber | Raw | item | V1-Required | Factory output |
| RAW-CHEMICAL | Chemicals | Raw | item | Candidate | Only if required by a real chain |
| RAW-MINERAL | Mineral aggregate | Raw | item | Candidate | Construction chain |
| MAT-PLANK | Planks | Processed | item | V1-Required | Timber conversion |
| MAT-METAL-PART | Metal parts | Processed | item | V1-Required | Metal conversion |
| MAT-CEMENT | Cement | Processed | item | V1-Required | Construction material |
| MAT-GLASS | Glass | Processed | item | Candidate | Furnace chain |
| GOODS-TOOLS | Tools | Crafted | item | V1-Required | Construction/upgrade |
| GOODS-HARDWARE | Hardware | Crafted | item | Candidate | Multi-input workshop |
| GOODS-FURNITURE | Furniture | Crafted | item | Candidate | Residential upgrade |
| GOODS-FOOD | Food crate | Consumer | crate | Candidate | Household demand |
| WASTE-SOLID | Solid waste | By-product | unit | V1-Support | Requires sink |
| WASTE-WATER | Wastewater | By-product | unit | V1-Required | Water-consumption output |
| RECYCLED-MATERIAL | Recovered material | Recovered | item | Candidate | Bounded-yield input |

An item is admitted only if it has at least one producer, consumer/sink, storage policy and economic role. Do not inflate content count without a gameplay purpose.

## 3. Recipe record contract

```ts
interface RecipeDefinition {
  id: string;
  schemaVersion: number;
  buildingFamily: string;
  inputs: Array<{ itemId: string; quantity: number }>;
  outputs: Array<{ itemId: string; quantity: number }>;
  byproducts?: Array<{ itemId: string; quantity: number }>;
  durationSeconds: number;
  operatingCostProfileId: string;
  utilityDemandProfileId?: string;
  workforceProfileId?: string;
  unlockRuleId: string;
  cancellationPolicyId: string;
  outputReservation: "before-start" | "at-completion";
  offlinePolicyId: string;
  balanceEvidence: "uncalibrated" | "simulated" | "playtested" | "approved";
}
```

Enabled recipes require positive quantities and duration. Inputs are reserved atomically before a run unless staged consumption is explicitly designed. Output capacity is reserved or the recipe enters a deterministic blocked-output state. A completed run never vanishes because storage is full.

## 4. Initial recipe graph

| Recipe ID | Building | Inputs | Outputs | Duration | Status |
|---|---|---|---|---|---|
| REC-RAW-METAL-01 | Basic factory | Operating resources TBD | RAW-METAL | TBD | V1-Required |
| REC-RAW-WOOD-01 | Basic factory | Operating resources TBD | RAW-WOOD | TBD | V1-Required |
| REC-PLANK-01 | Workshop | RAW-WOOD | MAT-PLANK | TBD | V1-Required |
| REC-METAL-PART-01 | Workshop | RAW-METAL | MAT-METAL-PART | TBD | V1-Required |
| REC-CEMENT-01 | Factory/workshop | RAW-MINERAL + operating resources TBD | MAT-CEMENT | TBD | Candidate |
| REC-TOOLS-01 | Workshop | MAT-METAL-PART + MAT-PLANK | GOODS-TOOLS | TBD | V1-Required |
| REC-HARDWARE-01 | Workshop | MAT-METAL-PART + MAT-PLANK | GOODS-HARDWARE | TBD | Candidate |
| REC-GLASS-01 | Advanced factory | RAW-MINERAL + RAW-CHEMICAL + energy | MAT-GLASS | TBD | Candidate |
| REC-RECYCLE-01 | Recycling yard | Eligible WASTE-SOLID | RECYCLED-MATERIAL + residue | TBD | Candidate |

The starter loop must prove at least one full chain from raw input to a construction/upgrade consumer and one meaningful inventory decision. Recipe count is not a quality metric.

## 5. Consumer and sink registry

| Consumer ID | Consumes | Trigger | Priority | Failure behavior |
|---|---|---|---|---|
| CONS-BUILD-FOUNDATION | MAT-CEMENT and selected materials | Construction command | Reserved project stock | Project waits; no loss |
| CONS-BUILD-UPGRADE | GOODS-TOOLS and tier materials | Upgrade command | Reserved project stock | Upgrade waits visibly |
| CONS-TRADE-NPC | Eligible surplus | Player confirms listing | Reserved listing stock | Cannot list unavailable stock |
| CONS-POPULATION | Consumer goods, if enabled | Household interval | Defined cohort priority | Gradual, explained satisfaction impact |
| CONS-UTILITY-PLANT | Fuel/input if plant requires it | Simulation interval | Continuity policy | Controlled degraded state, warning first |

Every sink is explicit. Discard, sale, conversion and consumption are ledgered with timestamp, source, destination, quantity and reason.

## 6. Inventory and reservation semantics
Inventory states: Available; Reserved-for-production; Reserved-for-construction; Reserved-for-trade; In-transit; Blocked-output.

Invariant: available + all reserved + in-transit + blocked-output equals authoritative owned quantity, adjusted only by explicit production, consumption, spoilage (if designed), transfer or sale ledger entries.

Atomic operations: reserve, release, consume, produce, transfer, list, delist and sell. Every command has an idempotency key so duplicate delivery cannot duplicate inventory changes.

## 7. Production state machine
IDLE → QUEUED → RESERVED → RUNNING → COMPLETED → OUTPUT_STORED.
Alternative states: BLOCKED_INPUT, BLOCKED_OUTPUT, PAUSED, CANCELLED and DISABLED.

Transitions are persisted and replay-safe. Offline elapsed time cannot complete a recipe twice. Blocked state identifies missing item/capacity and an actionable recovery path.

## 8. Economy integrity checks
For each run: validate item references; reserve inputs; record operating and utility cost; apply outputs/by-products once; enforce storage capacity; write ledger entries; verify quantity accounting; emit telemetry; replay the command sequence and confirm deterministic results.

A transformation may change item count but must not create unbounded economic value without an explicit balancing cost. Currency creation and sinks must be separately accounted.

## 9. Offline and concurrency
- Recipe progress uses simulation time, not UI timers.
- Offline progression has an explicit cap and fairness policy.
- Re-entry is deterministic and idempotent.
- Competing reservations serialize or fail cleanly.
- Process death/reconnect cannot duplicate completion.
- Device clock changes cannot grant production.
- Future server-authoritative mode ignores client-submitted completion claims.

## 10. Balancing protocol
Do not approve quantities/durations until scenarios prove: a new player understands the first chain; warehouse pressure creates decisions without becoming a chore; no recipe dominates all profit states; NPC trading cannot be exploited for infinite arbitrage; queue waits are meaningful but not forced idle walls; offline return is useful without overwhelming storage; by-products have sinks; and poor choices are recoverable.

Each tuning change records parameter, old/new value, rationale, scenario results, regression impact and balance version.
