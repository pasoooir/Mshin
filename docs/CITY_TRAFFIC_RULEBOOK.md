# City traffic rulebook

## Purpose and scope

This document defines the deterministic traffic policy used by Mshin's city-road simulation. It is a game-simulation standard, not a claim that the game implements every rule of a particular country's road code. The policy prioritizes predictable movement, collision avoidance, clear road access and preventing one vehicle from blocking an entire neighborhood.

## Road side, lanes and speed

- Traffic keeps to the right. Each direction uses its own lane offset; opposing vehicles must never share the same lane center.
- City-road speed is capped at 30 km/h (the existing 4x calibrated simulation speed).
- The external motorway is capped at 120 km/h (the existing 16x calibrated simulation speed).
- Vehicles follow their assigned route. Overtaking and lane changes are not permitted until a lane-change model with swept-path collision checks exists.
- Vehicles may move only on roads connected to the permanent Gateway network.

## Following distance and queues

- A vehicle must stop when the same-lane gap reaches the hard minimum of 2.25 m.
- Below the preferred 5.5 m following gap, speed is reduced proportionally rather than allowing the vehicle to close at full speed.
- A follower never inherits the leader's four-second release. The four-second recovery is limited to the frontmost stopped vehicle and must never override a hard following gap or a junction reservation.
- A stopped queue advances from front to back as each leader creates safe space. Vehicles may not push through a queue, overlap, or pass a stopped leader.
- No vehicle may retain a stale junction reservation after it exits, is removed, or completes its route.

## Junction control

- Every T-junction and crossroad is a conflict zone.
- A vehicle must obtain that junction's exclusive reservation before entering. While a reservation is held, all other approaches wait; this prevents two route segments from occupying the same junction simultaneously.
- The reservation is released only after the vehicle has traversed the junction and is leaving its cell.
- The initial policy is conservative first-come reservation, not a simulated traffic-light system. Signal phases, explicit stop lines, right-of-way-by-approach, pedestrian crossings and multi-conflict concurrent turns are later extensions and must not be represented as implemented until they have working code and tests.

## Emergency vehicles

- Police and fire vehicles use the same collision and junction reservation protections as civilian traffic in this phase.
- Sirens or visual emergency equipment do not grant permission to overlap another vehicle or enter an occupied junction. Emergency priority/traffic pre-emption requires a separate tested policy.

## Verification requirements

- Test right-hand lane geometry in all four cardinal directions.
- Test hard-stop and proportional following behavior, including the four-second frontmost-only recovery.
- Test exclusive junction acquisition, denial while occupied, and release after clearance.
- Test cleanup of reservations after route completion or vehicle deletion.
- Keep Godot project validation, gameplay smoke, Android export and playable web build green before merging.
