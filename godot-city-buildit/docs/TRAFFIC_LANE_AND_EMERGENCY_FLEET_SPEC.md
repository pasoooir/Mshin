# Traffic lanes, road speeds and emergency fleet

## Scope

This implementation covers the five requested traffic changes in the current Godot world:

1. 4x movement multiplier on city roads and 16x on the external divided motorway.
2. Conservative speed calibration and explicit vehicle-capacity limits.
3. Automatic police and fire vehicle dispatch from completed, Gateway-connected stations.
4. Right-hand traffic on city roads and three correctly separated lanes in each motorway direction.
5. Same-route, same-lane following control with braking and a full stop before a vehicle can overlap the vehicle ahead.

## Speed calibration

The world scale is 1 unit = 1 metre. A base speed of 2.083333 m/s is multiplied by the requested road-class factor:

| Road class | Multiplier | Calibrated speed |
|---|---:|---:|
| City road | 4x | 30 km/h |
| External divided motorway | 16x | 120 km/h |

The motorway is represented by its own world-space-aligned route over the existing six-lane visual road at X = -55 m. It is not inferred from negative city-grid coordinates; negative city streets continue to use the city multiplier. Northbound and southbound traffic have separate one-way routes and do not make U-turns across the median.

## Lane discipline

- City traffic uses the right-hand carriageway for its direction of travel.
- Opposing city traffic uses the opposite side of the road centreline.
- City vehicle body width is 0.62 m and lane-centre offset is 0.30 m, fitting two opposing vehicles inside the existing 1.32 m base-road surface.
- Motorway traffic uses three directional lane centres on each side of the median (offsets 9.1 m, 5.8 m and 2.5 m from the centreline).
- Direction changes are connected through the junction path rather than snapping back across the road centre.
- The same right-hand offset rule is applied to civilian, police and fire vehicles.

## Safe following

Vehicles are compared only when they share the same route, direction and lane. The follower progressively slows below a 5.5 m gap and stops at or below a 2.25 m gap. A second spatial check protects close approaches at crossing routes. A stopped lead vehicle therefore holds the queue behind it; followers do not pass through or overlap it.

## Police and fire fleet

Every building type whose service_group is police or fire is eligible, including all small, standard and deluxe/precinct tiers. A station dispatches only when:

- construction is complete;
- the station has access to the Gateway-connected road graph; and
- the emergency fleet has an available slot.

The vehicle begins at the station's road-facing exit, uses the nearest connected road as its route entry, patrols the connected network and returns. Police vehicles have blue emergency lights; fire engines have red emergency lights and visible fire equipment. A station has at most one active patrol vehicle at a time; dispatch is retried on the interval if access is restored or a vehicle finishes.

## Automated acceptance coverage

GameplaySmoke checks:

- 4x city and 16x motorway factors and their calibrated km/h values;
- negative city coordinates are not misclassified as motorway;
- northbound/southbound motorway routes stay separate;
- opposing city lanes are on opposite right-hand sides;
- a following vehicle stops inside the minimum safe gap;
- an independent traffic fleet appears on the external motorway;
- every police/fire station tier is mapped to the correct service group;
- automatic dispatch, station-exit spawn, station identity and vehicle equipment for police and fire.

## Remaining realism boundaries

This is a deterministic lightweight traffic simulation, not a full national traffic-code simulator. Traffic lights, stop/yield priority, pedestrian right-of-way, overtaking rules, lane changes, incident-specific emergency dispatch and physical vehicle collision bodies remain separate future systems. The current acceptance specifically guarantees the requested speed classes, right-hand direction, emergency patrol departures and no same-lane vehicle overlap.