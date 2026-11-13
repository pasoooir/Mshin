# Mshin City Highway Gateway — Foundation Specification

**Status:** implementation requirements for the first playable city map  
**Reference:** EA's SimCity BuildIt beginner guide, especially its road, zoning, service, and city-growth rules. The highway gateway is an explicit Mshin world-layout requirement.

## Current implementation status (PR #416)

- [x] One original lightweight 3D car is spawned at the permanent city Gateway, routed by BFS through Gateway-connected road tiles to the farthest reachable tile, then returned to and removed at the Gateway.
- [x] The active route is cancelled if a road change disconnects any route tile from the Gateway graph.
- [ ] The current Gateway is still the city-side root, not a separate highway source/sink with physical ramps. One-way edges, lane direction, turn restrictions, congestion-weighted routing, segment-level traffic, and delivery/construction/emergency vehicle classes remain open.

## World layout

- The new city begins as an **empty, buildable terrain grid**. Do not pre-place residential, commercial, industrial, or service buildings.
- A permanent regional highway already exists along one outer edge of the playable city.
- Exactly one initial highway interchange/access connection leads from the highway into the new city.
- The access road joins the city's primary arterial/collector road, which becomes the first spine of the internal road network.
- The highway and its interchange are part of the 3D world, not a flat background image or decorative prop.
- The city terrain, road shoulders, embankments, barriers, and ground cover must meet cleanly. Camera zoom/pan bounds must never reveal white or unrendered space outside the playable world.

## Road hierarchy and geometry

1. **Regional highway:** divided, multi-lane, high-capacity road with separate carriageways, lane markings, shoulders, median/barrier, guardrails, signage, and realistic elevation/embankment transitions.
2. **Interchange ramps:** physically continuous ramps with smooth curvature and appropriate merge/diverge geometry; no abrupt road endpoints, floating pieces, or intersections through barriers.
3. **City gateway road:** a visibly wider arterial/collector than local streets, connected to the internal road graph at a clear junction.
4. **Local roads:** remain buildable by the player and connect to the existing road graph.

All geometry must use the project world scale (1 world unit = 1 metre), remain readable at the normal mobile camera zoom, and use mobile-conscious geometry/material batching.

## Functional connectivity

- The highway connector must be represented in the same authoritative road graph used by routing, traffic simulation, service reachability, and road-connected building validation.
- Vehicles must be able to enter the city from the highway and leave the city back onto the highway. Traffic must not merely spawn on the city grid without a valid gateway route.
- Initial traffic classes should include private cars, delivery/construction trucks, and emergency/service vehicles as their simulation systems become available.
- Route planning must respect directionality, lane/edge connectivity, turn restrictions, and congestion costs.
- A building/zone is road-served only when connected through the road graph to the gateway network; visual proximity alone is insufficient.
- The highway itself is immutable in the initial milestone. Player road tools may modify internal roads, but must not accidentally bulldoze the regional highway or disconnect the sole gateway.
- If the gateway or a critical internal connector is ever made unavailable by a later feature, show a clear warning and prevent silently accepting an unreachable city state.

## Gameplay progression aligned with the EA guide

- Roads are the prerequisite for functional city growth: buildings and zones must connect to a road.
- Residential zoning starts construction only when it has valid road access.
- Road build, upgrade, and bulldoze actions must update the road graph and dependent traffic/service calculations.
- The initial highway connection provides the city's external access; it does not pre-populate the city or bypass the player's road-building decisions.
- Future expansion zones must connect to the existing city network, rather than being independently usable islands.

## Mobile camera and presentation

- Keep the full playable terrain and highway gateway inside the camera's legal pan/zoom envelope.
- Pinch zoom must stop before any white/unrendered exterior becomes visible; the minimum zoom must preserve a useful full-city view.
- Keep highway and gateway legible in landscape on compact Android viewports; avoid excessive HUD obstruction.
- Use real road surface variation, lane markings, shadows, barriers, vegetation buffers, and terrain transitions. Avoid a uniform flat-green ground plane or placeholder road strip.

## Acceptance tests

### Deterministic road-graph tests
- The highway, ramp, gateway arterial, and internal road graph form one connected route.
- A vehicle can route from the highway source to a city destination and back to the highway sink.
- One-way edges and ramp merge/diverge directionality are respected.
- Road-connected zoning/building checks reject disconnected plots.
- Bulldozing or upgrading an internal road updates connectivity; the protected highway and gateway root remain intact.

### Browser/mobile acceptance
- Fresh city starts with empty plots, a visible highway on the map edge, and one clearly visible access connection.
- At least one simulated vehicle enters from the highway, traverses the city network, and exits via the gateway.
- The interchange remains visually continuous at normal zoom and at the minimum permitted zoom.
- Landscape mobile viewport shows only the playable world; no white exterior or missing terrain is exposed during pinch zoom and pan.
- No console errors, missing assets, or frame-blocking work during initial city entry.

## Scope boundaries

- This specification does not authorize copying EA/Maxis screenshots, models, textures, or other proprietary assets. Use original Mshin geometry or assets with verified redistribution rights and recorded provenance.
- This is a foundation milestone, not a claim that traffic AI, all vehicle classes, a complete interchange model, or physical Android performance are already implemented.
- Keep the initial city empty except for the fixed regional highway and its one access connection.
