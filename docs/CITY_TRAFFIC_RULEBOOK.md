# Mshin citywide intelligent traffic system

## Mission

The traffic system is a city-wide network simulation, not a collection of unrelated vehicle timers. Its priorities are, in order:

1. Prevent collisions, unsafe following and junction conflicts.
2. Keep vehicles moving and prevent gridlock.
3. Distribute traffic across viable roads instead of concentrating every vehicle on one route.
4. Respect road class, lane direction and vehicle purpose.
5. Preserve access for emergency services without allowing unsafe movement.
6. Expose measurable network health so road upgrades and city planning have visible effects.

This is a game traffic policy. It is not a claim that every clause of a particular country's legal traffic code has been implemented.

## System architecture

### 1. Road network

- RoadSystem is the source of truth for road tiles, connectivity, road levels and Gateway reachability.
- Vehicles may use only roads in the connected city network.
- The traffic manager reads the road graph and must not invent links across empty or disconnected cells.
- Road placement, removal and upgrades invalidate/recalculate network-derived state.

### 2. Citywide traffic intelligence

- TrafficManager owns the active fleet, network load observations, route selection and junction reservations.
- Road-cell load is measured from the current and next route segment of active city/emergency vehicles.
- Route cost combines road capacity (road level), live vehicle load and a junction traversal penalty.
- build_route_between uses a weighted shortest-path search over Gateway-connected roads. A longer alternative may be selected when the shortest road is materially more congested.
- Round-trip traffic destinations are rotated among farthest reachable cells so all vehicles do not repeatedly target one identical endpoint.
- Route planning must be deterministic for identical network/fleet state and must never return a disconnected road cell.

### 3. Road side, lanes and speed

- Traffic keeps to the right. Opposing directions use separate lane offsets.
- City-road speed is capped at 30 km/h (the existing 4x calibrated simulation speed).
- The external divided motorway is capped at 120 km/h (the existing 16x calibrated simulation speed).
- Vehicles follow assigned routes. Overtaking and lane changes remain disabled until swept-path collision checks and safe merge logic exist.
- Road upgrades influence route cost through their increased capacity; they do not authorize unsafe speed or following behavior.

### 4. Following distance and queues

- A vehicle must stop when the same-lane gap reaches the hard minimum of 2.25 m.
- Below the preferred 5.5 m following gap, speed is reduced proportionally.
- A follower never inherits the four-second recovery. That recovery applies only to the frontmost stopped vehicle and never overrides a hard following gap or denied junction reservation.
- Queues must advance from front to back as safe space opens. Vehicles may not push through, overlap or pass a stopped leader.
- A vehicle removed from the fleet must no longer contribute to traffic load, following checks or junction ownership.

### 5. Junction conflict control

- Every T-junction and crossroad is a conflict zone.
- A vehicle must acquire an exclusive reservation before entering a controlled junction cell.
- Other vehicles must wait while that conflict zone is occupied.
- The reservation is released after the vehicle leaves the junction cell, or when the vehicle is removed/completes its route.
- A denied reservation is a hard stop, including after the four-second frontmost recovery.
- The current implementation is conservative exclusive reservation, not a complete traffic-light controller. It does not yet implement signal phases, turn-specific conflict matrices, stop/yield signs or jurisdiction-specific right-of-way.

### 6. Emergency vehicles

- Police and fire vehicles use the same collision and junction safety rules as civilian traffic.
- Emergency appearance or sirens never permit overlap or entry into an occupied conflict zone.
- Priority dispatch, route pre-emption and safe signal switching are future work and must be implemented and tested before being described as operational.

## Roadmap: remaining intelligent traffic capabilities

1. **Adaptive junction controller:** per-approach queues, starvation prevention, protected turn phases, all-red clearance and demand-responsive green times.
2. **Right-of-way model:** explicit stop/yield behavior, turn priority and conflict-aware crossing movements.
3. **Dynamic rerouting:** periodically re-evaluate route costs and safely reroute vehicles around incidents, road closures and sustained congestion without teleporting or reversing through traffic.
4. **Lane discipline:** lane selection by intended turn, safe lane changes, merge zones, overtaking only where permitted and no crossing of solid/unsafe boundaries.
5. **Emergency priority:** dispatch to incident coordinates, route selection, safe signal pre-emption and automatic restoration of normal phases.
6. **Pedestrian safety:** crosswalk occupancy, pedestrian phases and vehicle stop lines.
7. **Incident response:** stalled vehicles, blocked roads, crash clearance and temporary capacity reduction.
8. **Citywide monitoring:** per-road speed/load, queue length, junction delay, throughput, travel time and gridlock detection with actionable city feedback.

## Verification requirements

- Validate route endpoints and every intermediate cell against Gateway-connected roads.
- Prove that route cost rises with live occupancy and that a lower-cost alternative is selected when available.
- Test road-level capacity influence without violating speed ceilings.
- Test all four cardinal right-hand lane geometries.
- Test hard-stop/proportional following and frontmost-only four-second recovery.
- Test exclusive junction acquisition, denial, release and cleanup after vehicle deletion.
- Test route distribution and repeatability with a fixed network/fleet state.
- Keep Godot validation, gameplay smoke, Android export and playable web build green before merging.
- Never mark a roadmap capability complete from a static string check alone; require behavior-level tests.
