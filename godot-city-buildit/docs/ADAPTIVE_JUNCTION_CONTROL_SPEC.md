# Junction movement safety, right-of-way and rerouting

## Implemented in this slice

- **Movement conflict detection:** each entering vehicle registers its incoming and outgoing road cells. Lane-offset movement segments are compared; intersecting paths are rejected, while opposing straight-through movements on separated right-hand lanes are classified as compatible. The current signal scheduler still grants one approach green at a time.
- **Right-of-way:** under right-hand traffic, an approach yields when a queued vehicle is present on its right. A waiting approach receives a fairness override after 8 seconds so circular priority cannot starve it indefinitely.
- **Downstream clearance:** a vehicle cannot reserve a junction movement unless its exit cell is part of the Gateway-connected road network and is not currently occupied or being entered by another vehicle.
- **Reservation lifecycle:** movement reservations are per vehicle and are removed when the vehicle leaves the junction, completes its route, is deleted, or is pruned from the active fleet.
- **Closure/incident rerouting:** when the road graph changes or an incident calls `set_road_cell_blocked(cell, true)`, active city vehicles with invalid routes attempt a new weighted route from their current/nearest connected road cell to their original/nearest surviving destination. Clearing the block makes the road available to future routes and restores its effective traffic capacity. Only trips with no remaining connected path are retired.
- The adaptive green/yellow/all-red phase controller remains a separate admission gate. The four-second frontmost congestion crawl cannot bypass a denied junction phase.

## Safety boundaries

The movement geometry is a lane-offset segment approximation on the road grid, not a full swept-volume physics model. The right-hand rule is an approach-level yield rule with an 8-second fairness override, not a claim of complete jurisdiction-specific legal compliance. Exit clearance checks the immediate downstream cell, not a multi-cell storage bay. Highway vehicles remain outside city-road closure rerouting. The block API is available to incident systems, but automatic wiring from collision/wreck incidents is not yet implemented in this slice.

## Regression coverage

GameplaySmoke checks opposing straight-through compatibility, crossing conflict, right-hand yielding, bounded starvation override, disconnected and occupied downstream exits, active-vehicle rerouting around a removed road cell, and automatic rerouting after an explicit temporary road-cell blockage. Existing signal clearance, road connectivity and four-second stop recovery contracts remain in place.

Static validation checks the new movement, exit-clearance, right-of-way and rerouting APIs. CI results must be reported from actual workflow runs.
