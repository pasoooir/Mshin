# Production Capacity & Cashflow Replay

## Purpose

This deterministic simulator replays explicit production actions against the current Mshin production rules. It is intended for capacity and cashflow scenario analysis, not for generating player demand or pretending that every ready item sells.

Runtime code:
- `scripts/economy/ProductionCapacitySimulator.gd`
- `scripts/economy/MacroEconomySimulator.gd`

Smoke coverage:
- `tests/macro_economy_smoke.gd`

## Contracts taken from the live game code

| Area | Simulated behavior | Live implementation |
|---|---|---|
| Factory concurrency | Every factory slot runs independently; the building's configured `production_slots` is the parallel limit | `ProductionComponent.start_factory`; `BuildManager.building_types` |
| Store queue | One active job per store building; other slots are FIFO waiting jobs | `ProductionComponent._start_next_store_order` |
| Input reservation | All recipe inputs are validated and removed atomically when a manual store order is accepted into its queue | `ProductionComponent.start_craft`; `StorageManager.remove_items` |
| Completion | A timer makes the slot ready; it does not itself move goods into City Storage | `ProductionComponent.refresh_slots` |
| Warehouse | Collection requires free capacity; failed collection leaves the ready job in its slot | `ProductionComponent.collect`; `StorageManager.add_item` |
| Depot | Listing removes goods immediately; a listing becomes ready after 120 seconds; only explicit collection credits Simoleons; at most four active listings | `TradeManager.list_for_sale`, `_process`, `collect_sale` |

The simulator uses the actual catalog data supplied by the caller or captured from the live autoloads. Store duration overrides are captured from `ProductionComponent.get_item_production_time`, so store-star timing is not replaced with a guessed multiplier.

## Action schema

Every action is explicit and includes `at_seconds`.

- `start_factory`: `facility_id`, `item_id`. Starts one item in the first free factory slot. Factory slots do not have a hidden waiting queue in the current game; a full factory rejects the start.
- `enqueue_store`: `facility_id`, `item_id`. Reserves the complete `requires` BOM and occupies one free store queue slot. If any ingredient is missing or no slot exists, the action is rejected without partially consuming stock.
- `collect`: `facility_id`, `slot_index`. Collects exactly one ready item, only if the warehouse has one free unit. The optional `item_id` must match the slot.
- `depot_list`: `listing_id`, `item_id`, `quantity`. Requires `depot_operational=true`, an available one of four depot slots, and sufficient inventory. Goods leave storage at listing time.
- `depot_collect`: `listing_id`. Credits the catalog unit value times quantity only after at least 120 seconds have elapsed. Early collection is rejected and does not credit money.

A successful depot collection emits a `production_sale` cash event which `MacroEconomySimulator` adds to the `production_sales` source bucket. The same item cannot be sold twice because listing removes it from inventory and the listing is consumed on collection.

## Live city capture

`ProductionCapacitySimulator.capture_live_city_config(horizon_seconds, actions)` snapshots:
- Current City Storage inventory and capacity.
- Existing production components, actual slot counts, operational status, factory/store identity, and store-star duration overrides.
- Existing ordinary queue/production slot states and remaining timers.
- Current Trade Depot operational status and active listing timers.

`MacroEconomySimulator.simulate_live_city(config)` attaches that snapshot and replays the supplied `production_actions`.

The live snapshot currently refuses to run while an AUTO CHAIN job is active. Those jobs are dependency-managed by `ProductionManager`; treating them as ordinary manual queued jobs would start them before recursively scheduled ingredients exist. This is an explicit safety gate, not a silently approximated result.

## Output

The production result includes:
- Ending item inventory, used/free warehouse slots.
- Input quantities consumed and output quantities collected.
- Active/queued/ready-uncollected jobs by facility and slot.
- Rejected action count and a timestamped production log.
- Explicit depot sale cash events and collected sales total.

The macro result adds collected production sales to its normal Simoleon event ledger. Craft completion itself does not create money.

## Known limitations — remain unchecked until implemented and tested

1. Full replay of AUTO CHAIN dependency graphs, shared intermediate reservations and multiple concurrent roots.
2. Dynamic operational outages during the replay horizon; live capture currently snapshots the initial operational state.
3. Raw material and intermediate inventory cost-basis tracking. Current production sales affect cashflow, but catalog values are not treated as cash purchase costs. Therefore net Simoleons is not yet an accounting-grade net profit figure.
4. Explicit delivery-order consumption of produced stock is not yet coupled to production inventory; current delivery-order cash events remain scenario inputs to the macro simulator.
5. Demand, probability of finding a buyer, market competition and automatic sell-through remain intentionally unmodeled.
6. Physical Android acceptance and final balance calibration.

No capacity, demand, sale rate, or recipe value is invented by this simulator. All scenario actions and all numerical catalog inputs must be traceable to the current game data or explicitly labelled scenario assumptions.
