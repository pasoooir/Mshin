# Capital Region — Market, Trade, Supply Chain & Interregional Commerce System

**Status:** Design proposal only; not approved for V1 implementation.  
**Authority:** The V1 content catalog remains the sole authority for operational IDs and release status. This specification adds no operational IDs and changes no V1 status.

## 1. Objective and principles

Define a coherent economic exchange system connecting production, inventories, households, businesses, municipal projects, freight, markets and other regions. Trade must create observable value through goods actually produced, reserved, transported, delivered, sold or consumed—not through decorative counters or arbitrary money transfers.

- A listed offer is not a completed sale; a purchase order is not a shipment; dispatch is not delivery.
- Every good has a canonical item identity, unit, quality/state where modeled, ownership and location.
- Stock cannot be sold, consumed, promised or transported more than once.
- Price, demand, supply, inventory and transport are distinct concepts with traceable causes.
- No infinite NPC buyer, free freight, guaranteed profit, instant interregional transfer or money creation.
- Every trade and stock movement is deterministic, auditable and idempotent across retry, save/load and offline catch-up.
- Unmodeled markets, goods, regions and price effects are explicitly Not modeled.
- All numeric prices, quantities, rates, margins, capacities, lead times, elasticities, fees, caps and thresholds remain TBD until balanced with evidence.

## 2. Market actors and exchange boundaries

Potential actors, subject to approved scope:
- player-operated producers and shops;
- households/consumer cohorts, only where a validated consumption model exists;
- municipal departments and approved public projects;
- modeled businesses and industrial facilities;
- external/interregional counterparties represented by bounded, data-driven NPC market participants.

A market venue may provide an interface, storage or transaction capacity only if explicitly defined; it is not automatically a source of demand, inventory or revenue.

Keep exchange contexts separate: internal production transfer; local city market; interregional import/export; municipal procurement; scripted mission/event exchange; and player-to-player trade only if multiplayer is ever approved. Do not mix their pricing, ownership, fees or accounting rules. NPC counterparties need finite budgets, finite demand or bounded contracts; they must not absorb unlimited goods at a fixed price.

## 3. Canonical goods, units and quality

The item/recipe registry remains authoritative for item identity and recipe inputs/outputs. This document creates no item IDs.

Every tradable item needs a canonical ID and registry version, base unit, permitted quantity rules, batch identity where traceability is needed, quality/condition only if modeled, storage compatibility, ownership, custody, current location and provenance. Never compare or add incompatible units. Conversions require explicit versioned rules with deterministic rounding and residual handling. Quality premiums, perishability, substitutes and hazardous handling remain disabled until defined and tested.

## 4. Supply, demand and market state

Keep distinct:
- **Potential supply:** theoretical production or stock capacity.
- **Available supply:** unreserved, usable inventory offered for sale.
- **Committed supply:** stock promised to an order or contract.
- **In-transit supply:** dispatched but not accepted at destination.
- **Delivered supply:** received and accepted quantity.
- **Demand:** eligible quantity requested for a defined interval and market.
- **Unfilled demand:** requested quantity not fulfilled.
- **Consumption:** validated removal by an authoritative consumer.
- **Spoilage/loss/return:** explicit stock movement with cause.

Demand may originate from actual recipes, approved household/business consumption, municipal procurement or bounded NPC orders. A market UI popularity indicator cannot create demand. Forecast demand is not an order; an order is not payment; payment is not delivery.

Supply-demand balance must disclose market, interval, units, coverage and source records. Do not imply a fully modeled real-world economy if only limited producers and buyers are simulated.

## 5. Price formation and price display

Price mechanisms are candidates requiring approval: authored fixed prices for controlled contracts; bounded local reference prices with explicit supply/demand inputs; negotiated/auction-like prices only if interaction and fairness are designed; interregional quotes including transport, fees, risk and settlement terms.

Any dynamic model must define market scope and interval, eligible supply/demand, inventory and order-book inclusion, approved price bounds, update cadence, smoothing/lag, rounding, currency, market depth/coverage, uncertainty, missing-data behavior and deterministic tie-breaking.

Display reference price, actual transaction price, gross proceeds, fees, freight, taxes where approved, net proceeds and settlement status separately. A quote is not guaranteed execution. Avoid arbitrary price swings and exploitable same-tick feedback. Numeric parameters remain TBD.

## 6. Orders, contracts and transaction lifecycle

An order records immutable order ID and idempotency key; buyer/seller and authorized scope; market and destination; item, quantity, unit and approved quality constraint; quoted/accepted unit price and currency; quote expiry; fees/freight/tax/payment terms; delivery interval and partial-fill policy; stock reservation and funding authorization; status history and source versions.

Suggested lifecycle: draft → quoted → submitted → validated → reserved → accepted → picking → dispatched → partially delivered/delivered → inspected → settled → closed. Terminal states may include rejected, expired, canceled, failed and disputed; exact vocabulary is a schema decision.

Validation checks seller ownership, usable stock, quantity, buyer funds/credit if approved, market access, contract eligibility, storage, route/freight feasibility and permissions. Reserve stock and funds atomically or use a recoverable saga with explicit compensation. Failed reservations must not leave orphaned funds or stock locks.

Partial fills require explicit remaining quantity and expiry/cancel behavior. Repeated taps, retries or reconnects must not duplicate orders, reservations, payment or delivery.

## 7. Inventory, warehousing and stock conservation

Maintain inventory by item, quantity/unit, location, owner, availability state and reservation. Separate usable available stock, reserved stock, picking/packing stock, in-transit stock, received-but-not-inspected stock, rejected/returned stock and damaged/expired/unusable stock.

For each item/location/interval, reconcile opening stock plus accepted receipts, production outputs and returns in, against closing stock plus consumption, accepted sales/shipments out, spoilage/loss and transfers out. The exact conservation equation must account for work-in-progress and transformations without double counting inputs and outputs.

A production output enters stock only on validated completion. A sale removes stock according to the approved dispatch/acceptance ownership rule, never both at dispatch and delivery. Warehouses have finite capacity and compatible storage rules; UI state cannot increase capacity.

## 8. Freight, routing and delivery

Freight uses the authoritative road/access graph and fleet/trip contracts. A shipment records origin, destination, item lines, quantity, vehicle/transport mode, crew where required, route graph version, path, dispatch time, ETA forecast, stops, custody and delivery evidence.

Lifecycle: planned → capacity reserved → loaded → dispatched → in transit → arrived → inspected/accepted → unloaded → closed.

A route or ETA is not proof of arrival. Blocked roads, vehicle restrictions, capacity, operating hours, staffing, fuel/energy and loading/unloading capacity can prevent or delay shipment if modeled. No teleportation or instant cross-region delivery.

Vehicle payload, speed, route cost, fuel use, freight price, travel time and loading throughput remain TBD. Decorative trucks have no economic effect. Cargo cannot simultaneously remain available at origin and destination.

## 9. Interregional commerce

Each region is an independent market scope with explicit connectivity and transfer rules. Interregional trade requires approved region eligibility, valid trade connection/transport route, compatible goods/storage, origin stock reservation, destination capacity, transport mode/schedule/costs, and deterministic arrival/inspection/rejection/return handling. Import/export restrictions, tariffs and multiple currencies require explicit approval.

Regional price differences do not guarantee arbitrage profit. Include freight, handling, fees, risk, delay, capacity and market depth. No region is an infinite sink/source. An abstract remote region still needs finite auditable stock, demand, budgets and contract capacity. Unlocking a region creates no free stock or instant route.

## 10. Municipal procurement and public supply

Municipal projects/services may place purchase requisitions against approved budgets and specifications. Integrate with municipal finance and district allocation.

A funded requisition is not a purchase; a purchase order is not inventory; delivery is not accepted until inspection. Public procurement distinguishes contract price, commitment, invoice, accepted quantity, payable and payment. Restricted grants and appropriations retain constraints. Emergency procurement requires separately approved policy and audit.

## 11. Business operations and market participation

A business offers goods only from valid production or owned stock and accounts for labor, inputs, operating costs, capacity, opening state and distribution. Nominal capacity is not actual output. Unstaffed, disconnected, unfunded or input-starved facilities cannot produce at full capacity.

Business revenue is recognized according to the approved accounting model and settlement event. Gross sales are not profit: show input costs, wages, OPEX, freight, fees, taxes where approved, returns and losses separately. Business closure, bankruptcy, credit and investment mechanics are not assumed V1 features.

## 12. Market integrity and exploit resistance

Prevent duplicate sale/transfer through concurrent orders; infinite NPC demand/budgets; guaranteed buy-low/sell-high loops; price manipulation through fake orders; duplicate production output during offline catch-up; shipment teleportation or stale-route bypass; stock duplication through partial delivery/returns/save-load; negative stock/funds hidden by rounding; sale of reserved/damaged/expired/shipped goods; double revenue recognition at order, dispatch and settlement; exploiting region unlocks to mint value; and circular same-interval price-demand-production feedback.

Use transaction IDs, idempotency keys, atomic reservations, deterministic ordering, event history and reconciliation. Compensation must be explicit and auditable.

## 13. Mobile-first market UX

Portrait-phone surfaces:
- market overview: selected market, update time, coverage and data confidence;
- item detail: available/reserved/in-transit stock, demand, reference price and history;
- buy/sell flow: quantity, unit, gross/net proceeds, fees, delivery and settlement;
- order list: status, expiry, partial fill and next action;
- warehouse: capacity, stock state and incoming/outgoing shipments;
- freight map: origin/destination, route status, ETA range and blockers;
- regional trade: unlocked connections, limits and total landed cost;
- business panel: production, stock, sales, expenses and bottlenecks.

Use readable units, distinguish quote from guaranteed price, provide large touch targets, safe-area support, localized numbers, accessible status labels and confirmation for irreversible actions. Charts show period and data coverage. Hiding an overlay cannot alter simulation.

## 14. Simulation order, persistence and determinism

Proposed phases, subject to integration review:
1. authoritative production completion and item transformation;
2. inventory reconciliation and storage validation;
3. demand/order generation from approved sources;
4. market quote/price snapshot calculation;
5. order validation and deterministic stock/fund reservation;
6. picking, freight scheduling and dispatch;
7. shipment movement and delivery/inspection;
8. consumption, settlement and ledger posting;
9. market/business metrics and next-interval forecasts.

Avoid same-tick circularity. A sale may influence a later market snapshot, not retroactively change its own order price. Exact phase boundaries and intervals require approval.

Persist order/contract states, inventory movements, reservations, shipment manifests, route graph versions, quote/price snapshots, settlement events, market rule versions and idempotency keys. Save/load preserves custody and prevents double fulfillment. Migrations reconcile in-flight shipments and open orders without granting goods or money.

## 15. Acceptance scenarios

1. Order exceeds available stock: reject or partially fill under explicit policy; never create negative stock.
2. Two buyers compete for stock: deterministic reservation winner; no double sale.
3. Retry an accepted order: no duplicate reservation or payment.
4. Complete a recipe: inputs consumed once and outputs enter stock once.
5. List reserved stock: it is unavailable to another order.
6. Dispatch a shipment: origin custody changes once; destination receives nothing early.
7. Block the route in transit: follow reroute/failure policy; no teleport.
8. Receive partial delivery: accepted, rejected and remaining quantities reconcile.
9. Cancel after reservation: stock/funds release exactly once.
10. Sell to NPC: finite demand/budget and auditable price; no infinite buyer.
11. Change market conditions: price changes only at the defined later snapshot.
12. Compare gross/net proceeds: freight/fees/costs reconcile to finance ledger.
13. Trade between regions: route, capacity, origin stock and destination acceptance required.
14. Unlock a region: no free goods, money or instant shipment appears.
15. Use restricted grant for procurement: invalid purpose is rejected.
16. Save/load with open orders and shipments: no duplicate or lost stock.
17. Offline catch-up: production, orders, freight and settlement are idempotent.
18. Small phone viewport: market/order workflows remain usable.
19. Missing market telemetry: show Not modeled/insufficient coverage, not fabricated price.
20. Long-run replay: no unbounded wealth, inventory or NPC demand creation.

## 16. Unresolved decisions and implementation gate

Market scope/actors; approved tradable item IDs; household/business demand sources; NPC budget/demand model; price formation/cadence; currency/rounding; quality/spoilage; storage/handling; order/contract state machine; partial-fill rules; settlement timing; freight modes and vehicle payload; route/region connectivity; fees/tariffs; regional abstraction; accounting recognition; multiplayer scope; performance and offline caps.

All numeric values remain TBD. Before implementation, approve market/item scope in the catalog; finalize item units and conservation contracts; choose price/order model; define atomic inventory/fund reservation; integrate freight and finance; add deterministic replay/concurrency tests; create professional editable market/warehouse/freight assets via specialist tools/plugins; verify commercial licenses, provenance and hashes; conduct mobile UX and real-device profiling; obtain explicit approval to leave design phase.

**Evidence status:** Documentation only. No market, dynamic pricing, NPC trading, order book, freight economy, interregional transfer or gameplay feature is implemented or device-tested by this document. Existing V1 IDs and statuses remain unchanged.
