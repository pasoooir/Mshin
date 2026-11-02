# Sims City — Art Direction and Visual Quality Standard

## 1. Visual identity

Create an original, warm, premium urban-simulation visual language: readable stylized realism with believable proportions, strong material separation, restrained color families and clear silhouettes. It must not imitate the proprietary visual identity, UI, maps, models or logos of another game.

The target is a polished, coherent city viewed at an oblique/isometric angle, with closer zoom levels revealing authored architectural detail. The same asset family must remain recognizable in city mode and player-driving mode.

## 2. Art pillars
- **Readable at gameplay zoom:** building category and road hierarchy are recognizable from silhouette and value grouping.
- **Believable urban composition:** coherent street widths, sidewalks, setbacks, entrances, rooflines, street furniture and service access.
- **Material discipline:** PBR materials only where supported and budgeted; avoid noisy textures and excessive material slots.
- **Consistent scale:** human, vehicle, road, door and floor dimensions follow a shared measurement guide.
- **Day/night legibility:** emissive windows and street lighting are subtle and performant.
- **Designed variety:** modular facade families and controlled variants avoid copy-paste repetition.

## 3. Palette and environment
Use district palettes rather than random asset colors: residential calm neutrals/greens, commercial warmer accents, industrial muted metals/concrete, civic landmarks distinct but not oversaturated, parks/natural areas with layered greens. Lighting and atmosphere unify all districts.

## 4. Asset families
1. Road kit: asphalt, lane markings, curb, sidewalk, crossings, junctions, roundabouts, bridges and tunnels.
2. Buildings: low/medium/high residential, local shops, offices, workshops, factories, schools, clinic/hospital, police/fire, utilities, parks and civic landmarks.
3. Vehicles: compact/private, taxi, bus, delivery van, truck, police, ambulance, fire engine, sanitation and player cars.
4. People: diverse stylized citizens with modular clothing, locomotion and interaction animations.
5. Street props: lamps, signals, benches, bins, signs, shelters, bollards, hydrants, trees and planters.
6. Nature: trees, shrubs, grass, water, shore, hills, clouds, rain and snow.
7. UI: consistent iconography, map overlays, charts, build tools, vehicle HUD and feedback states.

## 5. Professional plugin-led production requirement

All production-facing visual design must be led by the relevant connected professional tools/plugins, not improvised as a final asset directly in code:
- Amazing Drawing for block plans, street layouts, district concepts and system diagrams.
- OpenArt for approved concept sheets, orthographic references, character/vehicle/environment exploration and marketing art.
- Meshy only if a supported integration is connected/authorized; otherwise select a supported model-generation route. No unsupported service is assumed.
- Build 3D Game Rooms for structured environment/prop production and runtime export, following its mandatory gates.
- Runchat/Blender/Rhino where available for procedural geometry, assembly and validation.
- Figma for UI components, design tokens and mobile/desktop panel layouts.
- Canva for release graphics and promotional layouts.
- SketchMonkey Design Studio for CMF exploration on vehicles, service equipment and hero props.

The plugin output is a source artifact/reference, not automatically a shippable game asset. Every final asset must be imported and inspected in the actual Cocos/browser runtime.

## 6. Model and texture budgets

Set final polygon, texture, material and draw-call limits only after representative-device measurement. Each asset record must include:
- dimensions and scale reference;
- polygon/triangle count and LOD levels;
- UV and texture resolution;
- material count and shader requirements;
- collision proxy;
- animation skeleton/bone count if animated;
- file size and import settings;
- source prompt/reference and tool/version provenance;
- license/ownership and acceptance screenshots.

## 7. Visual acceptance

Reject assets with broken topology, non-manifold geometry where relevant, bad normals, stretched UVs, inconsistent scale, unreadable silhouette, unwanted text/logos, poor mobile performance, mismatched style or unclear license. Require at least one close view, one gameplay-distance view and a mobile screenshot in the real runtime.
