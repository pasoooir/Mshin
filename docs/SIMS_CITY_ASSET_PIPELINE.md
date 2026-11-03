# Sims City — Asset Production Pipeline

## 1. Purpose

Establish a repeatable professional plugin-led pipeline from brief to accepted in-game asset. No generated image/model is automatically approved for production.

## 2. Pipeline gates

### Gate A — Design brief
Record asset ID, role, gameplay distance, target platform, dimensions, scale, style, animation needs, collision needs, performance budget, source/ownership and rejection criteria.

### Gate B — Concept and references
- Amazing Drawing: city block, street, parcel or environment layout.
- OpenArt: approved visual reference sheets and controlled variants.
- Figma: UI assets and interaction components.
- SketchMonkey: CMF direction for vehicle/industrial equipment where useful.
Review silhouette, composition, readability, consistency and originality before model production.

### Gate C — Geometry/model
- Use Meshy only if a real connected/authorized integration is available; otherwise use the available supported modeling route.
- Build 3D Game Rooms: read its doctrine, lessons, pipeline, asset-pipeline and chosen adapter before starting. Follow all Function/Form/Runtime gates; do not submit paid generation before approval.
- Runchat/Blender/Rhino: procedural cleanup, assembly, openings, scale checks, collision proxies and export where the connected bridge is available.
- Preserve source files and provenance; never overwrite approved source assets destructively.

### Gate D — Technical validation
Check topology, normals, UVs, materials, textures, scale, pivot, collision, LODs, animation, file size, license and import settings. Run automated asset manifest checks and visual review.

### Gate E — Engine integration
Import into the actual target runtime. Verify materials, lighting, animation, collision, camera readability and mobile performance. Cocos import/scene verification is required before calling it Cocos-ready.

### Gate F — Acceptance and versioning
Store source/reference, exported runtime file, metadata, screenshot evidence, reviewer and acceptance result. Commit asset and manifest together. Reject and revise failures.

## 3. Required metadata schema

Each asset record must include:
- `assetId`, `name`, `category`, `version`;
- `sourceTool`, `sourcePromptOrBrief`, `sourceFiles`;
- `licenseOrOwnership`, `authoringDate`;
- `dimensions`, `scaleUnit`, `pivot`;
- `triangles`, `lods`, `materials`, `textures`;
- `collisionProxy`, `animation`;
- `targetRuntime`, `importSettings`, `fileSize`;
- `qaStatus`, `qaEvidence`, `knownLimitations`.

## 4. First production batch

After the vertical-slice brief and art direction are approved, produce:
1. one coherent road kit (straight, corner, T-junction, crossroad, sidewalk and crossing);
2. a small residential building family;
3. one local shop and one civic/service building;
4. one compact vehicle set and a small citizen character set;
5. street lights, trees, benches and signs.

The batch must be authored as a cohesive district, not a random catalog of unrelated models.

## 5. Repository organization

Use stable, descriptive paths such as:
- `assets/city/roads/`
- `assets/city/buildings/`
- `assets/city/vehicles/`
- `assets/city/characters/`
- `assets/city/props/`
- `assets/city/environment/`
- `assets/city/ui/`
- `docs/asset-reviews/`

Keep raw source files separate from optimized runtime exports. Do not put unreviewed output in production asset folders.

## 6. Definition of asset done

An asset is complete only when the source and provenance are retained, the runtime export passes technical checks, it is imported and visible in the real game, its mobile performance is acceptable, its visual review is approved, and evidence is attached to the relevant PR.
