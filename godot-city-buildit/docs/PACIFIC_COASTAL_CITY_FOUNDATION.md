# Pacific Coastal City — Los Angeles-Inspired World Foundation

## Design direction

The starter region is a fictional Southern California coastal city inspired by the broad spatial character of Los Angeles. It is not a literal map replica and does not use Los Angeles trademarks or claim geographic accuracy.

The player should enter a calm, mostly undeveloped city where the Pacific shoreline and the inland green edge are immediately legible. No surrounding mountain ranges, mountain silhouettes, tunnel portals, rural livestock or dirt-track scenery belong in this starter composition.

## Spatial composition

- The city remains the central, empty, buildable starter grid. Existing ownership, save migration, road placement and building placement contracts are preserved.
- The Pacific Ocean is on the eastern side of the city.
- The coastline is moved to approximately world X = 110, leaving the full initial city footprint inland.
- The sandy beach is widened to a 36 m transition band, with an additional green-to-sand dune transition.
- Deep ocean geometry extends offshore to X = 250; shallow turquoise water remains a narrow continuous band immediately outside the beach.
- A curved timber promenade follows the sampled coastline and is built as one mesh.
- Twenty-four palm trees are placed in a loose landscaped line between the inland green edge and beach. Trunks and fronds are each batched in a MultiMesh.
- Inland terrain uses a lush Pacific-green palette and an expanded tree belt. The procedural ground remains local/offline; no runtime asset downloads are introduced by this slice.
- Terrain tessellation is increased to 128 divisions and extends farther inland to avoid a narrow, visibly bounded starter island.

## Entry camera

The opening camera targets X=38 at the 150 m overview zoom, framed to show the buildable city, broad beach and Pacific water together. The player can zoom in to build and zoom out to read the overall city/coast relationship.

## Mobile rendering constraints

- Promenade geometry is one mesh.
- Palm trunks and crowns are two MultiMeshes, not per-tree nodes.
- Small grass and shoreline pebble details fade out by 95 m and do not cast shadows, keeping the overview composition light on mobile.
- Palm shadows are disabled; the existing single directional key light remains the only shadow-map owner.
- No additional external texture or model download is required for this foundation.

## Implementation boundary

This first slice establishes the landscape, coast, beach, promenade, palm landmarking, greener inland edge and opening camera framing. It does not claim a complete Los Angeles-scale street network or finished neighborhood architecture. Follow-up slices should add, in order:

1. A calm primary boulevard and connected secondary street hierarchy.
2. A beachfront park, beach access paths, lifeguard facilities and public spaces.
3. Low-rise coastal residential blocks and neighborhood retail.
4. Larger inland urban districts, employment and civic services.
5. More detailed city vegetation and local/offline architectural GLB assets.

## Acceptance

- Godot 4.3 project import and parse succeed.
- Visual smoke verifies the widened coastline, continuous offshore mesh, promenade, palm frond mesh and coastal-green palette.
- Gameplay smoke and existing save/build/road tests remain green.
- Web export launches in desktop and mobile Chromium.
- Android Debug APK exports and passes package/signature checks.
- A successful CI screenshot capture is not a substitute for manual review on a physical Android phone.
