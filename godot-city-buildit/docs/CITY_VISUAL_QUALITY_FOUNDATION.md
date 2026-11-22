# City Visual Quality Foundation

## Goal

Move the Godot 4.3 city presentation toward a high-production-value stylized mobile city-builder while preserving the GL Compatibility renderer, offline asset loading, mobile-first landscape controls, save/build behavior, and web export.

This is a staged art/technical-art plan, not a claim of visual parity with SimCity BuildIt. Visual parity requires side-by-side captures on the same device/resolution and human art review.

## Source audit (2026-11-22)

- Project settings already select Godot 4.3 and GL Compatibility for desktop and mobile.
- The starter scene already has a single shadow-casting key DirectionalLight3D, a non-shadowing cool fill, a 46-degree camera FOV, and a mobile-friendly far plane.
- WorldPresentation builds a 128-division procedural terrain, local grass/sand textures, regional palettes, curved coastline, shallow/deep water, promenade, palm batches, tree belts, and a procedural sky/fog environment.
- Terrain height is intentionally flat inside the initial 48 m owned city footprint and rolls gently outside it. This is correct for build placement, but the terrain currently has no explicit vertex ambient-occlusion term.
- Tree belts use MultiMesh for roots/trunks/crowns and a separate soft contact-shadow MultiMesh. The current broadleaf belt has one shared crown silhouette with per-instance scale/yaw/lean; palms are a separate silhouette.
- RoadSystem already creates connected road arms with asphalt, lane markings, raised curbs and sidewalks in a single ArrayMesh per tile. Its main cost risk is per-tile MeshInstance3D count and every tile casting shadows.
- HUD.gd is already a large dynamic UI system with custom-drawn badges, icons, panels and production feedback. A wholesale HUD replacement would risk breaking established touch and gameplay contracts.
- The project includes a visual smoke test and Android/Web CI. The existing visual smoke source still checks legacy meadow helper names; these checks should be retained only while those functions remain intentional compatibility fixtures, and should not be mistaken for proof that the meadow assets are active in the Pacific starter scene.

## Art direction

Use a clean, sunny, premium stylized 3D look: warm key light, restrained cool fill, readable saturated-but-natural palettes, broad silhouettes, meaningful facade details, softened contact shadows, and a calm opening composition. Avoid excessive bloom, heavy vignette, noisy ground clutter, overly dark ambient shading, or photoreal PBR settings that flatten the stylized palette.

## Delivery order

### VQ-01 — Terrain grounding and contact shading
1. Preserve a level owned/buildable footprint so road/building placement and grid math remain exact.
2. Keep rolling height variation outside owned land and fade it toward the shoreline datum.
3. Add low-cost vertex cavity/slope shading to the terrain mesh. This is a baked-style approximation, not screen-space AO.
4. Keep the placement grid hidden outside placement/build modes; expansion borders remain a separate state. The first implementation now wires this to building placement and road edit-mode signals.
5. Verify the coast, highway, terrain, and city plot do not z-fight or expose seams.

### VQ-02 — Vegetation silhouettes and density
1. Keep the existing MultiMesh pipeline and soft contact-shadow batch.
2. Add two additional broadleaf crown silhouettes (conical and umbrella/round) as separate shared meshes/batches; retain palms as their own species. Implemented: the starter greenbelt now batches round broadleaf, conifer, umbrella and palm silhouettes separately.
3. Cluster trees in designed groups and preserve road, plot, beach, and camera sightline exclusions.
4. Add a distance tier: full geometry near, simplified crown farther away, then fade/cull. Do not add per-tree billboard nodes.
5. Only one or two batches should cast real shadows; small foliage and distant LOD should not. Repeated city-road tile meshes also skip shadow casting while remaining shadow receivers.

### VQ-03 — Road presentation and draw-call budget
1. Preserve the current connected-arm topology and tile connectivity.
2. Keep asphalt, curb, sidewalk, and markings as merged surfaces per tile or region.
3. Introduce one shared material set and deterministic tile/world-space wear variation; no unique texture generation per tile.
4. Profile whether road tiles should be merged into spatial chunks (for example 8x8 tiles) while preserving placement updates and hit testing.
5. Keep lane markings readable at the normal mobile camera zoom; suppress fine markings at overview distances if needed.

### VQ-04 — Building architecture and asset pipeline
1. Prioritize a small curated hero set: starter home, corner shop, factory, school/civic building, and one tall landmark.
2. Each GLB must have correct real-world scale, pivot at ground center, applied transforms, sensible mesh/material count, collision separated from render meshes, and LODs where justified.
3. Preserve local/offline asset provenance and license metadata. Do not add runtime CDN downloads.
4. Use facade hierarchy: base/podium, main mass, roofline, window rhythm, balconies/awnings/signage, service access, landscaping, and readable silhouette.
5. Procedural geometry is fallback/variation, not a substitute for final hero assets.

### VQ-05 — Lighting and atmosphere
1. Keep one shadow-casting DirectionalLight3D as the key light.
2. Keep fill lights non-shadowing; warm key color and warm-neutral sky ambient should agree.
3. Use fog only as a subtle distance cue. No volumetric fog dependency in Compatibility.
4. Do not enable SSAO/SSIL/volumetric effects in the Compatibility target. Use baked vertex AO/contact-shadow meshes instead.
5. Keep glow disabled by default; test any subtle glow against low-end mobile GPU and browser captures before enabling it.

### VQ-06 — HUD polish without gameplay regression
1. Retain existing HUD.gd signals, control names, native touch handling, modal ownership, and safe-area layout.
2. Establish a shared Theme/StyleBoxFlat palette for cards, buttons, counters, selected/disabled states and popups.
3. Use NinePatchRect only for reusable panel frames with real nine-slice assets; avoid stretching icon art.
4. Prioritize hierarchy, contrast, spacing, tap target size, and calm screen composition over decorative gradients.
5. Validate portrait fallback, landscape, 854x480 through 1920x1080, and small phone safe areas.

## Godot Compatibility implementation notes

### Vertex cavity shading

Use a small finite-difference sample around each terrain vertex and multiply the authored vertex color by a restrained AO factor. The owned city remains flat and un-darkened. This is a one-time CPU mesh-build cost and works in Compatibility because it is vertex color, not a renderer-specific screen-space effect.

### Material defaults

- Grass/soil: roughness 0.92–1.0, metallic 0.0.
- Asphalt: roughness 0.94–1.0, metallic 0.0; subtle normal scale only.
- Concrete: roughness 0.88–0.98, metallic 0.0.
- Painted metal: roughness 0.45–0.7, metallic 0.15–0.45.
- Glass: use sparingly; avoid expensive transparency on repeated facade windows.
- Foliage: roughness 0.9–1.0; use vertex colors and shared textures.

### Performance budgets to measure

- Target 30 FPS minimum on a representative mid-range Android device at the default city overview; 60 FPS is the stretch target.
- Avoid more than one shadowed directional light.
- Keep foliage, shoreline stones, and repeated props in MultiMesh batches.
- Track visible draw calls, active shadow casters, mesh surfaces, texture memory, startup build time, and frame-time p95.
- Web and Android exports must use the same local assets and GL Compatibility path.

## Visual acceptance checklist

### Opening composition
- [ ] First entry is calm; empty buildable land is clearly readable and not visually noisy.
- [ ] Coast, city land, green edge, and access highway have clear spatial hierarchy.
- [ ] No unwanted mountain, creek, rural livestock, rock, or roadside props intrude into the intended starter composition.

### Terrain
- [ ] Owned build plots remain level and placement coordinates remain exact.
- [ ] Non-buildable terrain has subtle height variation with no sharp spikes or visible tessellation.
- [ ] Grass has broad and fine color variation without a repeating obvious tile.
- [ ] Sand/grass transition is continuous and meets water at the correct datum.
- [ ] Build grid is absent in normal play and legible only in build/placement mode.
- [ ] Vertex shading adds grounding without black halos or dark seams.

### Vegetation
- [ ] At least three distinct tree silhouettes are visible in the starter region, including palms where appropriate. The procedural pipeline now creates separate broadleaf, conifer, umbrella and palm batches.
- [ ] Scale, yaw, crown width, and color vary without obvious deterministic repetition.
- [ ] Trees are clustered intentionally and never overlap roads, plots, buildings, or beach access.
- [ ] Soft contact shadows remain stable and do not look like black discs.
- [ ] Distant foliage fades without popping.

### Roads
- [ ] Asphalt width reads correctly at overview and close camera distances.
- [ ] Sidewalks and curbs form continuous joins at straight, corner, T and cross intersections.
- [ ] Lane markings do not float, flicker, or become visual noise.
- [ ] Repeated road tiles do not cast redundant shadows; they still receive shadows from buildings and props.
- [ ] Road-to-building access looks intentional.
- [ ] Wear variation is subtle and shared; no per-tile seams.

### Buildings and materials
- [ ] Hero buildings have recognizable silhouettes and meaningful facade details.
- [ ] Window, roof, signage, entrance, and ground-contact details read at normal mobile zoom.
- [ ] No building category is represented by an unrelated generic placeholder.
- [ ] Materials have controlled roughness/metallic values and no plastic-looking highlights.
- [ ] All assets are local, licensed, and included in Android/Web exports.

### Lighting and rendering
- [ ] One clear warm key light produces readable directional form.
- [ ] Fill light lifts shadows without flattening the scene.
- [ ] Contact shading grounds trees and buildings without excessive darkening.
- [ ] Fog adds depth only at distance and does not wash out the city.
- [ ] No Compatibility-incompatible post-processing is required.
- [ ] No visible shadow acne, detached shadows, z-fighting, or shoreline gaps.

### HUD and interaction
- [ ] Currency, level, population, happiness, storage, and service alerts have clear hierarchy.
- [ ] Panels and buttons share a coherent theme and consistent corner/rim/shadow language.
- [ ] All touch targets remain usable on phone landscape.
- [ ] No HUD element blocks the city center or critical building feedback.
- [ ] One-finger pan, two-finger pan/pinch/orbit, selection, placement and modal touch ownership remain unchanged.

### Performance and delivery
- [ ] Godot 4.3 project imports and parses cleanly.
- [ ] GameplaySmoke and VisualPresentationSmoke pass.
- [ ] Android Debug APK exports successfully.
- [ ] Web export launches in desktop and mobile Chromium.
- [ ] Captures are inspected at actual PNG dimensions, not CSS-scaled screenshots alone.
- [ ] Mid-range Android profiling records FPS/frame-time p95, draw calls, shadow casters and memory.
- [ ] Physical Android landscape review is recorded separately from automated CI.
