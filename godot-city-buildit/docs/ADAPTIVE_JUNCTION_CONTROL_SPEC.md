# Adaptive junction controller and movement safety

## Adaptive approach phases — PR #466

- TrafficManager measures active vehicles queued for each incoming approach of a controlled T/cross junction.
- One incoming approach receives green at a time. Green duration grows with observed queue size and is bounded by 2.0 seconds minimum and 7.0 seconds maximum.
- A competing queue causes the current green to end when its approach empties; otherwise the maximum green duration bounds service time.
- Phase transitions use a 1.0-second yellow interval followed by a 0.5-second all-red clearance interval.
- The next approach is selected by accumulated waiting time, with queue size as a tie-breaker. The served approach's waiting time resets.
- A denied signal admission remains a hard stop. The four-second frontmost congestion recovery cannot override a red/yellow/all-red phase.

## Movement conflict, right-of-way and exit clearance — PR #467

- **Movement conflict detection:** each entering vehicle registers its incoming and outgoing road cells. Lane-offset movement segments are compared; intersecting paths are rejected, while opposing straight-through movements on separated right-hand lanes are classified as compatible. The current signal scheduler still grants one approach green at a time, so compatibility is not yet used to run two approaches simultaneously.
- **Right-of-way:** under right-hand traffic, an approach yields when a queued vehicle is present on its right. A waiting approach receives a fairness override after `JUNCTION_RIGHT_OF_WAY_MAX_WAIT_SECONDS = 8.0` seconds so circular priority cannot starve it indefinitely.
- **Downstream clearance:** a vehicle cannot reserve a junction movement unless its exit cell is part of the Gateway-connected road network and is not currently occupied or being entered by another vehicle.
- **Reservation lifecycle:** movement reservations are per vehicle and are removed when the vehicle leaves the junction, completes its route, is deleted, or is pruned from the active fleet.

## Road closure and incident rerouting — PR #467

- When the road graph changes, active city vehicles with invalid routes attempt a new weighted route from their current/nearest connected road cell to their original/nearest surviving destination.
- An incident system can call `TrafficManager.set_road_cell_blocked(cell, true)` to temporarily close a road tile. Active vehicles are rerouted, route planning avoids the blocked tile, and effective road capacity is reduced. Calling the API with `false` restores the tile to route planning and capacity.
- Only trips with no remaining connected path are retired.

## Safety boundaries

- Movement geometry is a lane-offset segment approximation on the road grid, not a full swept-volume physics model.
- Right-of-way is an approach-level yield rule with an 8-second fairness override, not a claim of complete jurisdiction-specific legal compliance.
- Exit clearance checks the immediate downstream cell, not a multi-cell storage bay.
- The block API is available to incident systems, but automatic wiring from collision/wreck incidents is not yet implemented in this slice.
- Highway vehicles remain outside city-road closure rerouting.
- Pedestrian phases, emergency pre-emption, protected turn phases, and rendered traffic-light props are not implemented here.

## Regression coverage

GameplaySmoke checks initial green admission, competing approach rejection, yellow/all-red clearance, fair handoff, opposing straight-through compatibility, crossing conflict, left-turn versus opposing straight conflict, right-hand yielding, bounded starvation override, disconnected and occupied downstream exits, active-vehicle rerouting around a removed road cell, temporary blockage rerouting, and effective capacity reduction/restoration.

Static validation checks the controller, movement, exit-clearance, right-of-way, blocked-road and route-recovery APIs. CI results must be reported from actual workflow runs, not inferred from this specification.
