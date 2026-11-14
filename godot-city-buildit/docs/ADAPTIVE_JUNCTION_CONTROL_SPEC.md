# Junction movement safety, right-of-way and rerouting

## Implemented in this slice

- **Movement conflict detection:** each entering vehicle registers its incoming and outgoing road cells. The controller compares lane-offset movement segments, rejects intersecting paths, and permits opposing straight-through movements when their right-hand lanes remain separated.
- **Right-of-way:** under right-hand traffic, an approach yields when a queued vehicle is present on its right. A waiting approach receives a fairness override after 8 seconds so a circular priority pattern cannot starve it indefinitely.
- **Downstream clearance:** a vehicle cannot reserve a junction movement unless its exit cell is part of the Gateway-connected road network and is not currently occupied or being entered by another vehicle.
- **Reservation lifecycle:** movement reservations are per vehicle and are removed when the vehicle leaves the junction, completes its route, is deleted, or is pruned from the active fleet.
- **Closure rerouting:** when the road graph changes, active city vehicles with invalid routes attempt a new weighted route from their current/nearest connected road cell to their original/nearest surviving destination. Only trips with no remaining connected path are retired.
- The adaptive green/yellow/all-red phase controller remains a separate admission gate. The four-second frontmost congestion crawl cannot bypass a denied junction phase.

## Safety boundaries

The movement geometry is a lane-offset segment approximation on the road grid, not a full vehicle swept-volume physics model. The right-hand rule is implemented as an approach-level yield rule and an 8-second fairness override; it is not a claim of complete jurisdiction-specific legal compliance. Exit clearance currently checks the immediate downstream cell, not a multi-cell storage bay. Highway vehicles remain outside city-road closure rerouting.

## Regression coverage

GameplaySmoke checks:
- opposing straight-through compatibility and crossing-movement conflict;
- yield to traffic from the right and bounded starvation override;
- rejection when downstream exit space is disconnected;
- existing signal clearance, route connectivity and four-second stop recovery contracts.

Static validation checks the new controller, exit-clearance, right-of-way and rerouting APIs. CI results must be reported from actual workflow runs.
