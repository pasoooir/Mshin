# Mshin City — Realistic 3D World Acceptance Specification

Status: binding implementation backlog, 2026-11-04
Scope: **City-building game only.** Racing remains a separate product slice with its own renderer, entry point, dependencies, tests and release gates. Do not change racing gameplay or renderer while implementing this specification.

## Non-negotiable visual direction

Build a genuinely three-dimensional, inspectable, large-scale city and world. Do not substitute flat images, billboard buildings, primitive placeholder boxes, or a uniformly green plane for completed assets. All major objects must have coherent geometry, materials, lighting and scale from every visible side.

## Ordered implementation backlog

1. **World scale and buildable land**
   - Establish a consistent real-world scale for buildings, roads, vehicles, trees, street furniture and people.
   - Make buildings around the city perimeter and player-buildable buildings visually consistent in size.
   - Provide broad, connected, clearly zoned buildable land and enough lots/streets for meaningful expansion.
   - Validate camera framing, distance readability and mobile performance at both neighborhood and city scale.

2. **Complete 3D building construction**
   - Every building must have modeled front, rear, left/right sides and roof; support close inspection and 360-degree orbit.
   - No flat facade-only assets or simplistic generic boxes.
   - Use varied architectural silhouettes, floor plans, rooflines, entrances, windows, frames, balconies, awnings, signage and rooftop equipment.
   - Houses: large, stylish, modern, distinctive real-world-inspired architecture; include luxury villas, duplexes, modern mansions and multi-storey residences. Do not use tiny, plain or repetitive houses.
   - Commercial: recognizable shops, supermarkets, hardware stores, cafés and restaurants, with storefront glazing, signs, canopies and lighting.
   - Civic/services: recognizable schools, hospitals, police and fire stations, administrative buildings and mosques.
   - Industrial: substantial factories and realistic industrial complexes with production halls, loading areas, chimneys/vents, offices and service yards.
   - Towers and skyscrapers: varied heights, structural rhythm, glazing and roof silhouettes.
   - Parks and service facilities must be designed as distinct assets, not recolored copies.

3. **Material and texture system**
   - Use 24-bit True Color RGB (16,777,216 possible RGB colors) with alpha where needed (RGBA8 / 32-bit storage); avoid palette-limited or flat-color-only surfaces.
   - Create and integrate the six local 512×512 PNG city maps under assets/city/textures/generated/: grass.png, asphalt.png, sidewalk.png, brick.png, concrete.png, roof.png.
   - Apply textures to the correct Cocos Creator 3.8.6 materials and surfaces: ground, roads, sidewalks, walls, roofs and building details.
   - Use physically plausible PBR channels where supported: base color, normal, roughness and metallic; use appropriate glass, stone, brick, concrete, wood, metal, roof tile and asphalt response.
   - Prefer high-quality real-world/photographic texture sources with clear licenses (e.g. CC0) when needed; retain optimized local copies and deterministic procedural fallbacks. Never make runtime rendering depend on a remote CDN being available.
   - Add multi-scale surface variation, weathering, seams, edge wear and natural detail; avoid obvious tiling and uniform green terrain.

4. **Natural environment and ground**
   - Create visibly varied grass, soil, gravel, sand, rock, planting beds and terrain transitions.
   - Add trees and shrubs with varied species, canopy shapes, trunk/bark and seasonal appearance; include parks, lawns and planted roadside strips.
   - Roads need lane markings, curbs, junctions, crossings, drainage and believable wear; sidewalks need paving patterns and edge transitions.
   - Add streetlights, signs, benches, barriers, utility poles, traffic signals and other appropriately scaled street furniture.
   - Use natural shadows and contact shading so buildings, trees and vehicles sit on the ground rather than float.

5. **Sky, atmosphere and lighting**
   - Render continuous natural sky-color gradients with a broad True Color spectrum, not a few flat bands.
   - Provide physically coherent daylight, sun direction, ambient fill, soft shadows, reflections and exposure/tonemapping.
   - Preserve the existing four-season/weather direction: season-specific foliage and sky, plus rain, snow and falling leaves where applicable.
   - Keep atmospheric changes deterministic where needed for reproducible tests and saves.

6. **People, animals and vehicles**
   - Add appropriately scaled, recognizable 3D people, animals and vehicles where the city simulation requires them.
   - Preserve animation/movement and collision/navigation behavior; do not use static decorative images as a substitute for simulated entities.
   - Maintain mobile-friendly level of detail, batching/instancing and sensible draw-call budgets.

7. **Visual quality and interaction**
   - Every major building and environment asset must remain coherent from front/back/sides/top and during 360-degree orbit.
   - Support close-up detail without broken UVs, missing faces, texture stretching, z-fighting or obvious seams.
   - Preserve construction timers: a newly placed building remains under construction and is not presented as complete/usable until its timer finishes.
   - Preserve mobile-first controls, landscape/fullscreen attempts where browser/device policy permits, and graceful fallback.

8. **Performance and delivery**
   - Keep city and racing dependency graphs, entry points, renderers and tests isolated. Shared code is allowed only when deliberately designed and regression-tested.
   - Use LOD, instancing, batching, texture atlases/mipmaps and frustum/distance culling where appropriate.
   - Test Cocos Creator 3.8.6 scene/material integration, browser behavior, save/load and mobile viewport performance.
   - Browser automation is not a substitute for physical Android/GPU/frame-time validation; record that limitation honestly.
   - No feature is complete based on documentation or asset generation alone: acceptance requires visible runtime integration plus tests and evidence.

## Completion rule

Work through items 1–8 in order, then sub-items individually. Record each as:
- ⬜ شروع‌نشده
- 🟡 در حال اجرا
- 🟢 تکمیل‌شده و تأییدشده (runtime integration + acceptance evidence)
- 🔴 شکست‌خورده/مسدود

Do not mark a feature complete because a file exists or a workflow passes unrelated tests. Do not merge or publish a release as a substitute for acceptance.

## Separate racing workstream

The existing racing-only PR #266 (feat/racing-photoreal-track-surfaces) remains separate. Its asphalt/grass/sand/snow/rock/concrete/bark/foliage RGBA8 procedural texture work and racing shader changes must not be mixed into city files or city acceptance claims.