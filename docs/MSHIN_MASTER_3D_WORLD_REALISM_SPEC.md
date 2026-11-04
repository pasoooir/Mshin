# MSHIN — Master 3D World Realism Execution Specification

**Binding product scope:** Every requirement in this inventory is mandatory. Work proceeds category by category; no category is silently dropped, substituted with a flat colour, or marked complete because a document or placeholder exists.

## Non-negotiable global standards

1. World scale: 1 Three.js world unit = 1 metre. Building footprints must occupy the number of 8 m city tiles defined by their real footprint; do not squeeze a 30 m building into a single 8 m parcel.
2. Colour: 24-bit sRGB output (8 bits/channel; 16,777,216 possible RGB colours). Interpolate and light in linear space. HDR is for lighting range and precision, not a substitute for 24-bit output.
3. Materials: PBR base colour, normal, roughness and metallic maps where physically appropriate; AO/height/displacement only where they visibly improve the asset. Data maps are linear, colour/albedo maps are sRGB.
4. Sources: prefer real photographic scans and licensed models. Track source URL, asset ID, author, licence, attribution and local/runtime file path. Never call procedural noise a photograph.
5. Viewing: complete geometry on front, back, left, right and top; camera inspection orbit 360 degrees; close-up and city-scale camera distances.
6. Rendering: realistic shadows, reflections, atmospheric depth, exposure/tone mapping, anti-aliasing, mipmaps, anisotropic filtering and no abrupt LOD popping.
7. Performance: texture streaming, KTX2/Basis variants, instancing for repeated props, bounded draw calls, GPU-memory budgets and mobile quality tiers. Do not reduce building dimensions to improve performance.
8. Proof: actual GitHub Pages runtime screenshots/video, browser tests, mobile landscape tests and performance evidence. CI green alone is not visual acceptance.

## Required building categories

| Category ID | Persian name | Real-world target dimensions (W × D × H) | Required visual identity |
|---|---|---:|---|
| house | خانه | 12 × 15 × 7.5 m | windows, doors, roof, gutters, porch/balcony, yard |
| shop | مغازه | 8 × 10 × 5.5 m | deep storefront glass, sign, awning, entrance |
| tower | برج | 28 × 28 × 90 m | floor bands, curtain wall, balconies, podium, roof plant |
| hardware_store | فروشگاه ابزارآلات | 22 × 18 × 8 m | industrial retail frontage, loading bay, parking apron |
| school | مدرسه | 42 × 30 × 12 m | wings, classroom rhythm, entrance, courtyard, playground |
| cafe_restaurant | کافه و رستوران | 18 × 16 × 7 m | dining glazing, terrace, canopy, outdoor seating |
| mosque | مسجد | 32 × 38 × 22 m | dome, minaret, prayer hall, portal, courtyard, tilework |
| supermarket | فروشگاه بزرگ | 38 × 28 × 9 m | wide entrance, loading dock, sign, parking, service yard |
| factory | کارخانه | 60 × 42 × 16 m | industrial bays, vents, chimneys, pipework, loading docks |
| office | ساختمان اداری | 24 × 20 × 32 m | curtain wall, lobby, floor bands, canopy, roof plant |

The catalogue dimensions are starting architectural targets; variants may differ but must preserve metre scale and believable proportions. The simulation must be extended to support multi-tile footprints, rotation, collision/occupancy checks, road access and save migration before large assets are released to placement.

## Required world and environmental categories

- Sky and atmosphere: physically plausible zenith-to-horizon gradient, Rayleigh/Mie scattering, sun glow, atmospheric fog and smooth time-of-day transitions.
- Space objects: sun, moon, stars and night-sky depth; no flat colour backdrop.
- Clouds: volumetric or layered 3D cloud formations, multiple cloud families, light transmission, shadows and movement.
- Mountains and horizon: distant terrain silhouette, atmospheric perspective and scale continuity.
- Terrain and soil: varied ground elevation/material regions, soil/rock/sand/earth layers and transitions.
- Grass and ground cover: photo-derived albedo/normal/roughness, density and hue variation, blades/tufts near camera, wind animation and seasonal states.
- Trees and plants: multiple species, real canopy silhouettes, trunks/branches, seasonal foliage and scale variation.
- Water: depth colour, reflection, refraction, normal waves, shoreline and weather response.
- Roads and markings: photographic asphalt, cracks/patches, lane markings, crosswalks, wet/dry states, curbs and sidewalks.
- Street furniture: lights, traffic signals, signs, benches, bins, barriers, bus stops and utility cabinets.
- Vehicles, pedestrians and animals: consistent metre scale, complete visible models, animation, shadows and road/sidewalk behaviour.
- Parks, playgrounds, bridges and infrastructure: real materials, geometry, accessible paths, railings and appropriate scale.

## Per-category completion gates

A category is 🟢 only when all are true:
- a real, complete model/texture set is present and source/licence is recorded;
- it is wired to gameplay placement or world generation, not merely catalogued;
- metre dimensions and multi-tile footprint are validated;
- all sides and 360-degree orbit are inspected;
- PBR maps and full 24-bit sRGB colour output are verified;
- mobile landscape and desktop browser acceptance pass;
- no major console/network/asset errors;
- performance budget and LOD transitions pass;
- screenshots/video from the actual deployed game are attached.

## Execution order

1. Stabilize renderer and fix existing mobile browser failures.
2. Lock world scale, multi-tile footprint and camera inspection.
3. Complete ground, grass, road, sidewalk and terrain material library.
4. Complete sky, sun/moon/stars, clouds, fog, mountains and weather.
5. Complete building families one by one: house, shop, hardware store, cafe/restaurant, school, mosque, tower, supermarket, factory, office.
6. Complete vehicles, pedestrians, trees, parks, street furniture and infrastructure.
7. Integrate asset streaming, KTX2, LOD, draw-call/GPU budgets and mobile quality tiers.
8. Verify deployed runtime and publish evidence for every category.

**Current truth:** this specification and catalogue define the full scope. They do not mean every asset is already implemented. Existing accepted code remains separate from pending visual acceptance.
