# Adaptive junction controller and movement safety

## Adaptive approach phases — PR #466

- TrafficManager measures active vehicles queued for each incoming approach of a controlled T/cross junction.
- One incoming approach receives green at a time. Green duration grows with observed queue size and is bounded by 2.0 seconds minimum and 7.0 seconds maximum.
- A competing queue causes the current green to end when its approach empties; otherwise the maximum green duration bounds service time.
- Phase transitions use a 1.0-second yellow interval followed by a 0.5-second all-red clearance interval.
- The next approach is selected by accumulated waiting time, with queue size as a tie-breaker. The served approach's waiting time resets.
- A denied signal admission remains a hard stop. The four-second frontmost congestion recovery cannot override a red/yellow/all-red phase.
- New entry requires an explicit controller-owned green state; a missing/stale phase is never interpreted as implicit green.
- A vehicle that already holds a movement reservation retains permission to clear the junction through yellow/all-red. The reservation is released only after the vehicle reaches the downstream cell or is removed/rerouted.
- If every queued approach yields to traffic on its right, the controller stays all-red until an approach reaches the 8-second fairness threshold; it does not grant an immediate fallback green.

## Movement conflict, right-of-way and exit clearance — PR #467

- **Movement conflict detection:** each entering vehicle registers its incoming and outgoing road cells. Lane-offset quadratic Bezier centre-lines are sampled into eight segments; every segment pair is checked for intersection, so curved turn paths are considered instead of comparing only one straight chord. Conflicting movements are rejected; opposing straight-through movements on separated right-hand lanes remain compatible. The current signal scheduler still grants one approach green at a time, so compatibility is not yet used to run two approaches simultaneously.
- **Right-of-way:** under right-hand traffic, an approach yields when a queued vehicle is present on its right. A waiting approach receives a fairness override after `JUNCTION_RIGHT_OF_WAY_MAX_WAIT_SECONDS = 8.0` seconds so circular priority cannot starve it indefinitely.
- **Downstream clearance:** a vehicle cannot reserve a junction movement unless up to two downstream route cells are Gateway-connected, unblocked, and neither occupied nor being entered by another active vehicle. The check uses the vehicle's actual route and allows a shorter remaining route at trip completion.
- **Reservation lifecycle:** movement reservations are per vehicle and are removed when the vehicle leaves the junction, completes its route, is deleted, or is pruned from the active fleet.

## Road closure and incident rerouting — PR #467

- When the road graph changes, active city vehicles with invalid routes attempt a new weighted route from their current/nearest connected road cell to their original/nearest surviving destination.
- An incident system can call `TrafficManager.set_road_cell_blocked(cell, true)` to temporarily close a road tile. Active city vehicles are rerouted, new round trips and weighted route planning avoid blocked cells, and effective road capacity is reduced. Calling the API with `false` restores the tile to route planning and capacity.
- `TrafficManager.set_road_cell_blocked_by_source(cell, source_id, blocked)` tracks independent closure owners. A collision and roadwork incident can both block the same tile; clearing one source cannot reopen the tile while another source still owns a closure. The legacy `set_road_cell_blocked` API is retained as the `manual` source.
- Only trips with no remaining connected path are retired.

## Safety boundaries

- Movement geometry is a sampled lane-offset quadratic Bezier centre-line approximation on the road grid, not full swept-volume vehicle-body physics.
- Right-of-way is an approach-level yield rule with an 8-second fairness override, not a claim of complete jurisdiction-specific legal compliance.
- Exit clearance checks up to two downstream route cells; it is still a finite look-ahead rather than a complete downstream queue/storage simulation.
- The source-aware block API is ready for incident systems, but this repository does not yet contain an implemented collision/wreck incident producer that automatically calls it.
- Highway vehicles remain outside city-road closure rerouting.
- Pedestrian phases, emergency pre-emption, protected turn phases, and rendered traffic-light props are not implemented here.

## Regression coverage

GameplaySmoke checks initial green admission, competing approach rejection, yellow/all-red clearance, fair handoff, opposing straight-through compatibility, crossing conflict, left-turn versus opposing straight conflict, curved movement sampling, right-hand yielding, bounded starvation override, disconnected/occupied first and second downstream exit cells, active-vehicle rerouting around a removed road cell, blocked-cell avoidance for new trips, temporary blockage rerouting, independent overlapping incident ownership, and effective capacity reduction/restoration.

Static validation checks the controller, movement, exit-clearance, right-of-way, blocked-road and route-recovery APIs. CI results must be reported from actual workflow runs, not inferred from this specification.
