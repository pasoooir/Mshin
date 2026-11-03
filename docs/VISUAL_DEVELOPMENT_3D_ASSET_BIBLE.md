# MSHIN — Visual Development, 3D Asset Bible & Plugin Production Pipeline
Version: 0.1.0-design | Status: Draft art direction and pipeline specification
Target: Cocos Creator 3.8.6 | Platforms: Android/iOS | Visual identity: original Mshin

## 1. Visual north star
Create a polished, readable, welcoming miniature city with strong architectural identity and clear operational feedback. The city should feel alive at normal phone scale, while buildings, roads and controls remain legible on small screens. The art direction may learn from broad genre conventions but must not copy EA/SimCity proprietary models, textures, UI, logos, names or distinctive compositions.

## 2. Visual principles
1. **Readability before micro-detail:** silhouette, footprint and operational state must read at gameplay zoom.
2. **Coherent scale:** doors, floors, vehicles, trees, road widths and citizens share one scale reference.
3. **Material discipline:** use a controlled PBR/material vocabulary; avoid noisy textures and excessive roughness variation.
4. **Color as information:** operational warnings use consistent semantic colors; decorative color cannot imitate warning states.
5. **Layered detail:** silhouette and large forms first, medium architectural features second, micro-detail only where visible.
6. **Mobile performance:** every asset has LOD, texture budget, overdraw review and a fallback.
7. **Originality and provenance:** source, license, generation method and edits are recorded for every shipped asset.

## 3. Art style system
The proposed direction is stylized-realistic 3D: believable proportions and materials, simplified forms, carefully controlled detail, warm readable lighting and distinct regional architectural language. Final camera projection, outline treatment, saturation range, palette and shadow softness require a visual target board and approval before production.

### 3.1 Shape language
- Residential: approachable, varied rooflines and clear tier progression.
- Industrial: robust silhouettes, readable machinery and restrained emissions effects.
- Civic/service: recognizable purpose through massing, signage and access apron.
- Utilities: clear functional identity, pipes/tanks/turbines as readable large forms.
- Roads: clean hierarchy, visible intersections, markings and curb logic.
- Vehicles: readable class silhouettes and color coding without copying branded liveries.

### 3.2 Regional identity
Capital region establishes the base architectural grammar. Later regions may vary climate adaptation, roof form, facade material, vegetation, street furniture and palette, while preserving interaction readability and shared scale.

## 4. Required asset package per building
- Orthographic/front/side/top concept views and gameplay-angle target.
- Silhouette thumbnail at actual phone gameplay size.
- Scale sheet against road, citizen and vehicle.
- Low/medium/high geometry or equivalent LOD strategy.
- Material slots with texture resolution and compression targets.
- Collision/selection proxy separate from decorative geometry.
- Construction, idle, operating, degraded and upgrade visual states as applicable.
- Icon, build-menu thumbnail and selection highlight.
- Night lighting and emissive review if night mode exists.
- Mobile capture at minimum supported device profile.
- Asset provenance/license record and source project reference.

## 5. Vehicles, citizens and environment
Vehicles need class-specific dimensions, wheelbase, turning envelope, lights, loading/response states and LOD. Citizens need a small modular variation set, readable silhouettes and pooled animation. Trees, rocks, water, street furniture and props must be grouped into reusable sets with clear collision and culling behavior. Decorative props cannot block placement unless explicitly tagged as blockers.

## 6. Plugin-first professional production workflow
Specialist plugins and external tools are expected to be used where they materially improve production quality. They are not a substitute for review:
1. Generate visual references and concept variations with image-generation/design plugins.
2. Curate and approve a coherent direction board; reject inconsistent styles.
3. Generate or model mesh candidates using suitable 3D tools/plugins.
4. Inspect topology, scale, UVs, normals, material slots and license/provenance.
5. Retopologize/optimize and create LODs in a proper 3D pipeline.
6. Bake/author textures and validate compression/memory.
7. Import into Cocos Creator and verify materials, lighting, animation and selection proxies.
8. Capture target-device screenshots/video and compare against approved references.
9. Record asset ID, source, plugin/tool, prompt or source file, edits, license and reviewer.
10. Run visual regression and performance checks before acceptance.

A plugin-generated render or mesh is only a candidate asset. It is not considered integrated or production-ready until inspected, optimized, imported and tested in the actual game.

## 7. Technical budgets
Exact triangle, texture, material, draw-call, animation and memory budgets are per-device-profile decisions. Establish a low-end Android baseline and a higher tier; measure representative scenes at maximum expected density. Never set a budget from desktop preview alone. Track:
- visible and total triangles;
- draw calls/material switches;
- texture memory and dimensions;
- shader variants;
- overdraw and transparent layers;
- animation update cost;
- load time and peak memory;
- frame-time percentiles, not only average FPS.

## 8. Lighting and VFX
Lighting must preserve object readability and avoid expensive dynamic lights everywhere. Prefer baked/stylized lighting where appropriate, with selective dynamic effects for important events. VFX such as smoke, steam, water, sparks, construction dust and emergency lights require density limits, pooling, distance culling and reduced-motion alternatives. Effects must reflect actual simulation states; a factory should not emit production smoke when disabled unless explicitly cosmetic.

## 9. Animation-state mapping
Animation is driven by authoritative state:
- construction: staged progress;
- operational: loop only while active;
- blocked/disabled: appropriate reduced or stopped activity;
- emergency: dispatch/response cues;
- upgrade: tier transition and completion feedback.
Animation completion cannot mutate economy or simulation state.

## 10. Accessibility and mobile readability
- Critical state is not conveyed by color alone.
- Text/icons remain legible at supported scale settings.
- Avoid rapid flashing and excessive camera shake.
- Provide reduced-motion options for impactful effects.
- Selection outlines and invalid placement are distinguishable over all terrain.
- UI iconography has consistent visual grammar and labels.
- Avoid tiny hotspots; hit areas are larger than visible decorative details.

## 11. Asset review gates
Concept approval → blockout approval → technical art validation → in-engine integration → device review → performance approval → release sign-off. Any stage may reject an asset with documented reasons. No placeholder or unlicensed asset enters a release build.

## 12. Open decisions
Final projection/camera angle; palette and material reference board; minimum device; texture compression formats; mesh/LOD budgets; night cycle; weather/VFX scope; plugin/tool selection; asset licensing policy details. Resolve these through a curated visual prototype and measured device tests.
