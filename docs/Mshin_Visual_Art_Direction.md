# Mshin Visual Art Direction — Coastal Living City

Status: active art-direction contract  
Target renderer: Godot 4.3, GL Compatibility, WebGL 2 / mobile  
Primary reference: SimCity BuildIt  
Secondary references: Townscaper, Dorfromantik, Islanders, A Short Hike, Spiritfarer, Cozy Grove, Stardew Valley and Kind Words

## 1. Research synthesis

### Commercial city and life-simulation references

| Reference | What works visually | Borrow for Mshin | Avoid |
|---|---|---|---|
| SimCity BuildIt | Dense, colorful 3D diorama; readable building silhouettes; layered skyline, parks, roads, shorelines and landmarks; bright daylight and strong material separation | The main target: believable city scale, rich but controlled colors, recognizable building categories, landscaped public space and a camera composition that makes the city feel alive | Copying its exact assets/UI; making every surface equally saturated; filling the starter city before the player builds |
| The Sims Mobile | Polished stylized 3D props and architecture; warm lighting; clear material hierarchy; character-scale details | Use warm window light, inviting storefronts, readable furniture/props and consistent material response | Overly toy-like proportions or character-centric clutter in the city overview |
| Animal Crossing: Pocket Camp | Rounded, friendly forms; soft value transitions; recognizable props; seasonal decoration and strong object readability | Gentle tree crowns, inviting park props, curated seasonal accents and friendly silhouettes | Turning the entire city into a miniature toy set or relying on pastel color alone |
| Hay Day | Distinctive hand-crafted illustration language, rounded silhouettes and playful rural props; its visual identity avoids generic hyper-cute mobile art | Use expressive farm props, crop/field patterning and warm rural details outside the buildable grid | Flat 2D illustration treatment across a 3D city; excessive outlines or cartoon exaggeration |

SimCity BuildIt was explicitly designed as a mobile-first re-interpretation of the franchise, with its own visual language rather than a straight port of the PC game. Its commissioned city key art emphasizes busy city life, distinctive buildings and multiple activities in one readable composition. Sources: [EA/SimCity BuildIt interview](https://simscommunity.info/2014/10/14/apptrigger-qa-jason-willig-simcity-buildit/), [Studio Piñata — SimCity BuildIt River](https://pinata.fi/portfolio/simcity-buildit-river-keyart/). Hay Day's art direction was intentionally distinctive and resisted generic cuteness: [PocketGamer — 10 years of Hay Day](https://www.pocketgamer.biz/supercell-looking-back-10-years-of-hay-day-part-one/).

### Indie references: transferable principles

| Game | Distinctive visual lesson | Suitable transfer | Do not copy |
|---|---|---|---|
| Townscaper | Simple geometry becomes appealing through carefully designed transitions, corners, roof/wall relationships and procedural shape changes | Make terrain-to-beach, road-to-sidewalk, trunk-to-canopy and building-to-ground junctions deliberate; no raw flat intersections | Its extremely simplified block architecture as the city’s final asset quality |
| Dorfromantik | Restrained palette, silhouette-first readability, handcrafted biome sets, vertex-color variation and a painterly idealization of real landscapes | Use curated biome palettes, broad color fields, controlled texture density and a single readable key light | Its sparse tile-board composition or low-detail asset density as a substitute for a living city |
| Islanders | Minimalism, strong silhouettes, clean negative space and fast visual recognition | Keep tree/prop silhouettes distinct and preserve open space around roads and build plots | Empty minimal landscapes; Mshin needs richer near-camera detail |
| A Short Hike | Low-resolution 3D, flat cohesive shading, clear silhouettes and palettes sampled from real landscape photography | Use nature-photo references for palette tuning, warm/cool separation and readable hills | Pixelation and deliberately low-resolution rendering; these conflict with the BuildIt target |
| Spiritfarer | Hand-drawn, painterly shapes, layered scenery and emotionally warm color | Borrow layered depth, warm/cool atmosphere and soft transitions at distant scenery | 2D watercolor outlines or flat 2.5D treatment for the 3D city |
| Cozy Grove | Gentle earth/pastel colors, hand-drawn edge character and color as mood/feedback | Keep secondary props and distant scenery quiet; use color to make important areas feel welcoming | Bleached monochrome terrain or outline-heavy 2D styling |
| Stardew Valley | Strong tile-level value grouping, crop/soil contrast and immediate material readability | Make grass, tilled earth, paths, crops and planted areas distinguishable at a glance | Pixel-art scale, tile repetition or 2D asset proportions |
| Kind Words | Deliberate restraint and low visual pressure | Keep UI surfaces calm and let the world carry the color | Its sparse room-scale scene as a target for a city builder |

Evidence: Townscaper's creator discusses how material and shape transitions make simple structures interesting ([Game Developer interview](https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making)). Dorfromantik's team describes its art-style sheet, vertex-color/biome pipeline, silhouette-first checks and restrained single-sun lighting ([80 Level, 25 May 2026](https://80.lv/articles/how-dorfromantik-expands-its-cozy-world-through-minimalist-design)); the team also describes landscape-painting references and an idealized rather than literal representation of nature ([Game Developer interview](https://www.gamedeveloper.com/business/sparking-joy-through-tile-placement-in-idyllic-village-builder-i-dorfromantik-i-)). A Short Hike's creator explains the choice of cohesive flat shading, low-resolution readability and a palette sampled from landscape photography ([PlayStation Blog](https://blog.playstation.com/2021/08/05/crafting-a-tiny-open-world-a-look-behind-the-scenes-at-the-creation-of-a-short-hike/)). Islanders' official description confirms its colorful island landscapes and minimalist city-building focus ([official site](https://playislanders.com/islanders1)). Cozy Grove's palette and watercolor-like progression are discussed in [Coziness in Games: Second Homes, Audiences, and Esthetics](https://pmc.ncbi.nlm.nih.gov/articles/PMC13197054/).

## 2. Mshin's final art direction

**Coastal storybook realism**: a polished, colorful 3D city diorama with believable physical scale, hand-curated natural palettes, soft atmospheric depth and high-clarity silhouettes. It should feel like a real place designed by an artist, not a procedural green plane decorated with random objects.

Priority order:
1. SimCity BuildIt-level city readability, scale, color separation and material richness.
2. Dorfromantik/Townscaper discipline: coherent palettes, attractive transitions, silhouette and negative-space control.
3. A Short Hike/Spiritfarer warmth: natural color references and layered atmosphere, without pixelation or 2D imitation.
4. Mobile/Web performance: all art must remain local, deterministic and batched.

### Working palette — Pacific coastal temperate

| Role | Color |
|---|---|
| Deep shaded grass | #829067 |
| Cool meadow sage | #89966D |
| Sunlit meadow | #B3A071 |
| Dry olive grass | #A9956B |
| Straw field | #B5A071 |
| Exposed soil | #987B5D |
| Warm earth | #A07B55 |
| Sandy beach | #D9C18D |
| Wet sand | #A99570 |
| Shallow water | #3D9A9A |
| Pacific deep water | #07527C |
| Warm sunlight | #FFE0B3 |
| Distant haze | #C8DDD5 |

No single hue may dominate the entire visible ground. Every overview frame should show a deliberate mix of shaded grass, sage meadow, dry/olive field, soil, beach and water.

## 3. Current problems and priority

1. **Terrain reads as one green carpet**: previous shader relied on low-contrast smooth waves; palette-only changes did not create clear field boundaries.
2. **Ground composition lacks a strong hierarchy**: broad fields, dirt tracks, creek edges, scrub and stone clusters must read as separate materials, not one green surface.
3. **Near-camera nature needs richer silhouettes**: grass clumps, shrubs, fieldstones and tree crowns must be visible at actual mobile zoom.
4. **Water and shoreline need layered depth**: deep ocean, shallow turquoise band, wet sand and foam must remain visually separate.
5. **Lighting must sculpt volume**: one clear key sun, soft sky fill, controlled contact shadows and atmospheric distance.
6. **The buildable starter plots must remain flat and visually calm**; surrounding nature must carry the relief and detail.

## 4. Phased implementation roadmap

### Phase A — Visible terrain rescue (current)
- Replace the low-contrast meadow shader with broad world-space biome fields whose sage, olive, straw and earth values remain distinct under Compatibility lighting.
- Keep the base meadow in a visible mid-value sage range; do not let deep green dominate the full playable ground.
- Use broad sage, olive, ochre/straw and warm-soil fields at approximately 150–250 m visual scale; each field must span a visible landscape region rather than appearing as scattered camouflage spots. The dominant meadow must not render as deep emerald green.
- Build broad world-space biome regions with softened irregular boundaries, then layer medium exposed-earth islands and fine mottling without a dark-green carpet.
- Preserve the flat 48 × 48 m starter build area and coastline alignment.
- Keep all generated materials local and deterministic.
- Validate with actual WebGL screenshots at overview, medium and near zoom. Reject the build if more than half of the visible natural ground reads as a single dark-green value group.

### Phase B — Ground dressing
- Cluster multi-blade grass, low shrubs, small flowers, stones and occasional bare-earth patches.
- Green terrain must never read as a smooth, uninterrupted flat sheet: build layered shrubland with overlapping low bush silhouettes, varied clump heights, irregular spacing and deliberate breathing gaps.
- Use an artistic but natural green family: shaded woodland green, eucalyptus/sage, olive, muted sunlit leaf tips and occasional warm dry-grass accents. Avoid neon green and avoid a single repeated hue.
- Blend shrub density gradually from the sandy/dune edge into the meadow: sparse salt-tolerant scrub near the coast, mixed low grasses and shrubs in the transition, richer clustered meadow vegetation farther inland.
- Use natural clusters and empty breathing spaces, not uniform scatter or a repeating grid.
- Keep roads, building plots and camera interaction clear.
- Use shared low-poly cluster meshes, MultiMesh batches and distance-based density/LOD; do not create one scene node per bush or grass blade.

### Phase C — Trees and landscape framing
- Distinct broadleaf, conifer, umbrella and palm silhouettes.
- Multi-layer crowns with readable volume, per-instance palette variation and subtle wind.
- Contact shadows and three LOD tiers; no per-tree draw-call explosion.

### Phase D — Coast and lighting
- Deep Pacific water, translucent-looking shallow water, wet sand, irregular foam and shoreline props.
- One shadow-casting directional key light; warm non-shadow fill; sky ambient; restrained fog.
- No expensive SSAO/SSIL requirement for Compatibility/WebGL.

### Phase E — Biomes and seasonal variation
- Biome palette sets first; seasonal material/foliage swaps second.
- Snow accumulation only for arctic regions; dry soil and sparse scrub for desert; lush but still varied tropical ground.
- Do not duplicate complete geometry for each season.

## 5. Terrain system specification

The terrain is divided into three visual bands:
- **Buildable city**: 48 × 48 m, flat, neutral, clean and unobstructed.
- **Natural transition**: rolling meadow, curated dirt tracks, creek channel, scrub clusters, fieldstones and irregular groves.
- **Coast**: meadow-to-dune transition, sand, wet-sand edge, foam, shallow water and deep ocean.

Godot 4.3 Compatibility currently uses a deterministic, unshaded vertex-colour terrain material so authored palette values survive mobile WebGL lighting consistently. Broad continuous world-space fields define sage, olive and sunlit grass; a subordinate irregular soil mask and dry-grass field add variation. Do not use coordinate-quantized palette indices, hard-edged colour tiles or scattered overlay islands: they create visible stripes or camouflage at overview distance. Climate tint is applied after the base field. If a procedural shader is reintroduced, it must preserve the same value separation in Compatibility and pass real mobile captures.

Suggested height rules:
- Starter plots: exactly 0 m.
- Surrounding meadow: broad 0.8–2.5 m rolling relief, softened near roads and coast.
- Beach: fade continuously to sea datum; no visible land/water gaps or floating ribbons.
- No mountain backdrop or high-frequency bumpy noise under buildable plots.

## 6. Vegetation system

- **Canopy silhouette**: 3–5 overlapping lobes or layered cards with visible depth; avoid single flat billboards and repetitive spheres.
- **Species**: broadleaf gum tree, umbrella tree, conifer, palm; each must remain recognizable at overview distance.
- **Palette**: shaded forest green, eucalyptus/sage, olive and occasional warm sunlit tips; no saturated neon green.
- **Placement**: clustered groves with irregular gaps, creek-side vegetation, roadside spacing and beach palms. Never place vegetation on roads or owned/buildable plots.
- **Wind**: subtle phase-offset canopy motion; trunk remains stable.
- **Batching**: MultiMesh by species and spatial chunk; three LOD levels; shadows only on hero/near trees where budget permits.

## 7. Water and shoreline

- Deep water: dark Pacific blue with broad wave movement and low-frequency specular glints.
- Shallow water: narrow teal/turquoise band following the sampled coastline.
- Surf: irregular foam segments and wet-sand darkening, not a uniform white outline.
- Coast geometry: same sampled coastline function for terrain, beach, shallow water and foam.
- Keep shader cost bounded; avoid per-pixel refraction or expensive screen-space effects in WebGL Compatibility.

## 8. Lighting and atmosphere

- One main DirectionalLight3D with shadows; use moderate shadow softness and avoid multiple shadow maps.
- Warm secondary fill with shadows disabled.
- WorldEnvironment: procedural sky, filmic tonemapping, sky ambient light and low-density fog.
- The ground's color palette must carry most of the mood; lighting should add form, not wash out the designed color separation.
- Check the scene in grayscale: roads, soil, grass, buildings and water must retain distinct value ranges.

## 9. Godot 4.3 implementation constraints

- Renderer: GL Compatibility; no Forward+/Vulkan-only features.
- Terrain: one merged ArrayMesh with baked continuous world-space vertex colours and a Compatibility-safe material.
- Grass/trees/rocks: MultiMeshInstance3D batches; no one-node-per-blade/tree patterns.
- Terrain fields: deterministic low-frequency world-space functions; no coordinate-quantized palette bands, no expensive screen texture reads.
- Assets: local files in GitHub; no runtime CDN/HTTPRequest.
- Maintain a mobile frame-time budget; reduce near-detail density with distance and keep shadow casters selective.

## 10. Strict visual acceptance checklist

### Terrain
- [ ] At overview zoom, at least four distinct ground materials/biomes are visible without zooming in.
- [ ] The ground is not perceived as one green sheet at first glance.
- [ ] Broad sage, olive and straw fields dominate the terrain composition; exposed-earth islands remain secondary and do not resemble camouflage spots.
- [ ] Near-camera grass, scrub, creek banks, dirt tracks and stones are visible as separate silhouettes.
- [ ] The starter build plots remain perfectly flat and free of decorative clutter.
- [ ] Road edges and sidewalks remain clean; no grass or stones intersect asphalt.
- [ ] No visible seams, z-fighting, texture repetition or terrain/water gaps.

### Vegetation and water
- [ ] Tree species remain distinct at overview zoom.
- [ ] Canopies have volume and contact with trunks; no flat-card appearance at close zoom.
- [ ] Shallow water, deep water, foam and wet sand are clearly distinguishable.
- [ ] Shadows ground the trees/buildings without excessive dark patches.

### Camera and performance
- [ ] Overview, medium and near captures all read well at 844 × 390 mobile landscape.
- [ ] The visual composition remains attractive at the default camera framing.
- [ ] No runtime network dependency; offline start succeeds.
- [ ] Godot import, headless startup, gameplay smoke, WebGL Chromium desktop/mobile acceptance and Android export pass.
- [ ] Compare real screenshots before/after; source-level string checks alone are not visual acceptance.

## Reference sources
- [SimCity BuildIt mobile-first visual intent](https://simscommunity.info/2014/10/14/apptrigger-qa-jason-willig-simcity-buildit/)
- [SimCity BuildIt commissioned city-life key art](https://pinata.fi/portfolio/simcity-buildit-river-keyart/)
- [Hay Day art direction](https://www.pocketgamer.biz/supercell-looking-back-10-years-of-hay-day-part-one/)
- [Townscaper geometry and transitions](https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making)
- [Dorfromantik art pipeline and readability](https://80.lv/articles/how-dorfromantik-expands-its-cozy-world-through-minimalist-design)
- [Dorfromantik landscape-painting references](https://www.gamedeveloper.com/business/sparking-joy-through-tile-placement-in-idyllic-village-builder-i-dorfromantik-i-)
- [A Short Hike art direction](https://blog.playstation.com/2021/08/05/crafting-a-tiny-open-world-a-look-behind-the-scenes-at-the-creation-of-a-short-hike/)
- [Islanders official visual/biome description](https://playislanders.com/islanders1)
- [Cozy Grove color and coziness analysis](https://pmc.ncbi.nlm.nih.gov/articles/PMC13197054/)
