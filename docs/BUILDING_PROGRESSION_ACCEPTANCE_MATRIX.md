# MSHIN — Building Progression, Simulation Contracts & Acceptance Matrix
Version: 0.1.0-design | Status: Draft acceptance specification
Target: Mobile-first Cocos Creator 3.8.6

## 1. Purpose
A content item is not complete because its model exists or its panel renders. Completion requires correct placement, simulation, economy, persistence, mobile interaction, visual quality, failure handling and performance evidence.

## 2. Shared building lifecycle
Common states: Locked, Available-to-place, Placement-preview, Under-construction, Operational, Degraded, Paused, Upgrading, Disabled and Demolished (terminal historical record). Not every family uses every state, but transitions are explicit. No state may be inferred from a sprite or animation.

Rules:
- Invalid placement never charges currency or consumes materials.
- Confirmed placement creates exactly one instance.
- Construction progress survives app restart.
- Operational status derives from dependencies, not a UI toggle.
- Upgrade costs are reserved before work starts.
- Cancellation/refund rules are defined for each lifecycle state.
- Demolition previews losses and service impact and requires confirmation.
- Missing art cannot delete or corrupt the simulation entity.

## 3. Upgrade tier model
Use data tiers T0, T1, T2 and T3; localized labels may differ. Number of tiers is a content decision, not a universal assumption.

Each tier declares footprint, capacity/output, utility demand, workforce demand, service coverage/capacity, upkeep, traffic generation, construction inputs/downtime, visual package/LOD, unlock conditions and migration/rollback compatibility.

For every tier delta, provide a functional change or explicit cosmeticOnly flag, visual acceptance reference, balancing rationale and regression test. A larger-looking building must not silently imply more population, output or coverage.

## 4. Family-specific contracts and tests

### 4.1 Roads and intersections
Contract: one authoritative road graph for connectivity and routing.
- Place segment; graph edge appears exactly once.
- Remove segment; dependent access recalculates.
- Disconnected residences/services are reported.
- Junction turns and route costs are deterministic.
- Construction blockage safely invalidates routes.
- Vehicle replans after topology changes.
- Touch placement, rotation and cancel work on supported screens.
- Dense intersections remain within mobile frame/memory budgets.

### 4.2 Residential
Contract: occupancy, household demand and service exposure are simulation data.
- Legal frontage and terrain required.
- Occupancy never exceeds configured capacity.
- Population changes only through explicit rules.
- Utility shortfall and service deficit are reported separately.
- Household demand derives from cohort profiles.
- Demolition/relocation previews population and demand impact.
- Save/load preserves cohorts and satisfaction state.
- Visual occupancy cues match simulation state.

### 4.3 Factories and workshops
Contract: recipe queue, stock reservation and output are authoritative.
- Recipe cannot start without inputs.
- Concurrent queues cannot reserve the same stock.
- Completed output is stored once.
- Full storage enters visible blocked-output; no loss.
- Utility/workforce interruption follows declared policy.
- Process death and offline catch-up never duplicate output.
- Cancellation follows recipe refund policy.
- UI shows inputs, outputs, duration, queue and blocking reason.

### 4.4 Warehouse
Contract: capacity and inventory ledger are authoritative.
- Add stock up to capacity; overflow is explicitly rejected/blocked.
- Reservation reduces available stock, not owned stock.
- Release restores available stock exactly once.
- Listing reserves stock; delisting releases it.
- Save/load preserves reservation categories.
- No negative stock under concurrent commands.
- UI distinguishes available, reserved and in-transit stock.

### 4.5 Utilities
Contract: supply, demand, connection and capacity are independent dimensions.
- Connected demand within capacity is supplied.
- Over-capacity demand creates quantified deficit.
- Disconnected buildings are not marked supplied.
- Plant relocation previews affected consumers.
- Reconnection restores service on a defined simulation step.
- UI distinguishes disconnected, insufficient capacity, degraded and supplied.
- Demand scaling occurs only through explicit building/cohort data.

### 4.6 Waste
Contract: generation, collection, temporary storage and processing are separate.
- Waste has a defined source and interval.
- Fleet has route, time and capacity limits.
- Depot overflow is visible and has declared effects.
- Recycling yield is bounded and residue recorded.
- Waste does not disappear on app close or demolition.

### 4.7 Fire, police and health
Contract: service quality depends on capacity, operational state and route access/time.
- Service without road access cannot provide full response.
- Capacity exhaustion differs from geographic distance.
- Fleet/staff unavailability degrades response.
- Simultaneous incidents cannot exceed available units.
- Coverage overlay matches actual calculation.
- Recovery is deterministic and follows policy.
- Catastrophic loss requires clear warning and fair response window.

### 4.8 City hall and construction office
Contract: policy and project state are explicit.
- Budget changes are ledgered.
- Policy changes preview impacts before confirmation.
- Project queue survives restart.
- Materials cannot be consumed twice.
- Blocked project displays missing inputs and next action.
- Administrative UI is usable on mobile.

### 4.9 Trade depot
Contract: listing is an atomic stock-reservation transaction.
- Quantity cannot exceed available stock.
- Listing creation is atomic and idempotent.
- Sale removes reserved stock and credits currency once.
- Expiry/cancel releases stock per policy.
- NPC pricing cannot enable unbounded arbitrage.
- Network failure cannot produce double sale.

## 5. Mobile-first acceptance
- Primary actions are reachable one-handed where practical.
- Touch target minimums are defined in UI specification and verified on device.
- No essential action depends on hover, right-click or keyboard.
- Drag has tap alternative for accessibility and precision.
- Placement preview clearly communicates invalid reason.
- Camera gestures do not conflict with controls.
- Safe areas, cutouts and system bars are respected.
- Text remains legible at supported display scaling.
- Panels preserve selected-building context.
- Repeated taps are debounced at command boundary.
- Loading, offline and error states offer recovery actions.

## 6. Visual and technical acceptance
Every production building requires approved concept sheet and silhouette; scale reference against road/citizen/vehicle; material and texture budget; day/night readability; animation states mapped to simulation; LOD and overdraw review; collision/selection footprint separate from decorative mesh; icon and construction/upgrade variants; provenance and license record.

Plugin-generated assets are not automatically approved. They must be reviewed, optimized, integrated into Cocos and tested on representative devices. Plugins are production tools, not substitutes for QA or asset ownership checks.

## 7. Save, migration and deterministic simulation
- Instances reference stable definition IDs and schema versions.
- Save data stores state, not transient UI presentation.
- Migrations are versioned and tested from every supported prior schema.
- Commands are idempotent.
- Offline catch-up has documented maximum interval and fairness policy.
- Replaying the same command log and elapsed interval yields the same authoritative state.
- Missing definitions trigger safe migration/error handling, never silent deletion.
- Recovery preserves the last known valid snapshot.

## 8. Required test layers
| Layer | Examples | Gate |
|---|---|---|
| Schema | IDs, references, ranges, enums | 100% catalog validation |
| Unit | Recipe math, reservations, utility capacity | Critical invariants pass |
| Simulation | Offline intervals, overload, recovery | Deterministic replay |
| Integration | Road + building + service + economy | Core loop passes |
| UI | Placement, upgrade, inventory, recovery | Mobile flows pass |
| Visual | LOD, clipping, contrast, asset states | Approved reference |
| Performance | Frame time, memory, draw calls, load | Device budgets |
| Persistence | Restart, migration, interrupted command | No duplication/loss |
| Exploratory | Full warehouse, disconnected city | Recoverable outcomes |

## 9. Minimum end-to-end acceptance scenario
A clean profile must: place road; place starter residence; connect/supply minimum utilities; occupy residence and generate explainable demand; operate factory; produce raw material; store it; convert it in workshop; reserve crafted goods for upgrade; complete upgrade; close app and return after controlled offline interval; verify production, inventory, construction and budget consistency; inspect actionable event summary. No fake data, manual DB edits or developer-console intervention is allowed.

## 10. Defect severity
- Blocker: data loss/duplication, save corruption, exploit, impossible progression or core loop failure.
- Critical: incorrect population/economy/service state, unrecoverable deadlock or mobile control failure.
- Major: repeated usability/visual defect or incorrect but recoverable simulation.
- Minor: non-blocking cosmetic/copy defect.

## 11. Definition of Done
A family is complete only when catalog records are approved; assets and licenses verified; acceptance tests pass; mobile usability passes; save/migration/offline tests pass; minimum-device performance passes; no blocker/critical defect remains; and evidence links to exact content/schema version.
