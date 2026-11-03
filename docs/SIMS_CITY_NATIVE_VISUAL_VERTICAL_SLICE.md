# Mshin — Native City Visual Vertical Slice

## Purpose
The supplied SimCity BuildIt screenshots are the quality and mood reference: vivid natural greens, warm daylight, readable oblique city composition, detailed building silhouettes, dark asphalt, pale sidewalks, varied roofs and recognizable industrial equipment.

Create an original art identity. Do not copy SimCity BuildIt models, textures, UI, logos, maps or exact building designs.

## Corrected delivery direction
The previous city work improved a browser Three.js renderer. That is not the final delivery target. The shipping target is an Android APK built from Cocos Creator 3.8.6. This slice therefore lives under assets/ and is written against Cocos. Browser output is not the acceptance target for city visuals.

## Visual hierarchy
1. Ground: saturated but natural green terrain with subtle mottled grass texture; avoid a flat green plane in final art.
2. Road system: blue-charcoal asphalt, pale lane markings, raised light concrete curb, warm light-gray sidewalk.
3. Residential: cream plaster, muted brick, terracotta roof, pale trim, cool blue glass; pitched roof for detached homes and balconies/roof equipment for mid-rise buildings.
4. Commercial: stronger teal/blue identity, warm ochre fascia and restrained orange awning; large glazed storefront.
5. Industrial: neutral concrete and metal, visible loading bay, stacks, storage tank, pipework and safety-yellow accents.
6. Nature: multiple greens with darker shadow masses and lighter canopy accents; trees need distinct silhouettes.
7. Lighting: warm late-morning directional light, soft ambient fill and contact shadows. No oversaturated neon palette.

## Native slice in source
assets/scripts/CityVisualVerticalSlice.ts creates one deterministic sample block with:
- green terrain, asphalt, lane dashes, curbs and sidewalks;
- detached residential house with porch, chimney and windows;
- mid-rise apartment with facade rhythm, roof cap and balconies;
- commercial shop with glazed display and awning;
- factory with loading bay, stacks, tank, pipework and safety trim;
- pocket park with trees and a bench;
- street lamps.

The initial geometry uses a shared unit box mesh and cached materials. This is a composition and silhouette prototype, not final production art. Tree crowns and some roof forms are temporary blockout geometry. Real authored models, texture maps and LODs remain required.

## Texture production rules
Final assets must use authored, seamless or UV-correct texture sets where appropriate:
- grass: albedo + normal + roughness variation;
- asphalt: fine aggregate albedo + subtle normal + roughness;
- sidewalk/concrete: light warm-gray albedo + restrained roughness;
- brick/plaster: facade-specific albedo and normal, no noisy procedural over-detail;
- roof: terracotta or slate material with edge/trim geometry;
- glass: cool blue tint with controlled reflection/roughness;
- industrial metal: muted painted metal with selective wear, not grunge everywhere.

Flat-color blockout materials are not acceptable as final visual quality.

## Performance guardrails
- Share meshes and materials; do not create one unique material per window.
- Keep the first slice small and deterministic.
- Replace repeated primitive detail with atlas-backed meshes or instancing in the full asset family.
- Set final triangle, texture and draw-call budgets only after profiling on representative Android devices.
- Keep a gameplay-distance view and close-up view for every accepted asset.

## Acceptance gates
- [ ] Cocos Creator 3.8.6 imports the component without engine/type errors.
- [ ] The sample district is attached to a real city scene and renders in Editor Preview.
- [ ] The sample APK starts in immersive fullscreen landscape.
- [ ] Close-up and gameplay-distance screenshots show distinct house, apartment, shop and factory silhouettes.
- [ ] Ground, road, sidewalk, building and foliage materials are visually distinct.
- [ ] Texture assets replace flat blockout materials.
- [ ] Mobile frame-time, memory and thermal checks pass on a real Android device.

Until those gates pass, this is an in-progress native prototype, not a completed graphics milestone.
