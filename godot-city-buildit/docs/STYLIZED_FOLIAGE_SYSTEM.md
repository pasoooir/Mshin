# Stylized Foliage System — Mshin

## Scope
This system replaces the previous three sphere-lobe canopy batches in the coastal tree belt with a four-shape, crossed-card canopy renderer for Godot 4.3 GL Compatibility. It remains local/offline and is integrated into `WorldPresentation.gd`; it is not a standalone demo.

## Runtime structure
- `scripts/world/StylizedFoliageSystem.gd`: deterministic species assignment, 64 m spatial chunks, MultiMesh construction, three geometry tiers, soft leaf atlas generation and seasonal leaf emitters.
- `scripts/world/FoliageSeasonManager.gd`: tweened spring/summer/autumn/winter tint, canopy density, snow tint and falling-leaf intensity.
- `shaders/stylized_foliage.gdshader`: Alpha Scissor, per-instance variation, bent-normal lighting, low-cost back-light response and gentle wind.
- `scripts/world/WorldPresentation.gd`: builds one reusable branched trunk mesh, contact shadows and the foliage system for the existing natural tree-belt placements.

## Species
1. Round broadleaf canopy.
2. Tall narrow broadleaf canopy.
3. Soft tapered conifer canopy.
4. Fan-palm-like radial frond canopy. Existing beach palms remain separate coastal landmarks.

The trunk mesh has a central tapered trunk and four merged primary branches. Trunks, branches and roots share batched rendering. The foliage atlas is generated locally at startup and does not make network requests.

## LOD and culling
| Tier | Distance band | Crossed cards |
|---|---:|---:|
| LOD0 | 0–46 m | 8 curved cards |
| LOD1 | 38–118 m | 4 curved cards |
| LOD2 | 108–280 m | 2 cards |

Trees are grouped by 64×64 m world chunks and species. Every chunk owns its MultiMesh bounds and visibility ranges. The same tree placement appears once in each LOD tier; the engine selects visibility by range. The renderer does not create a per-tree Node3D.

## Shader and materials
- Soft alpha is authored in the local atlas; Alpha Scissor avoids expensive blended foliage.
- Bent normals are authored into the curved card mesh and used for soft directional response.
- `INSTANCE_CUSTOM` carries per-tree hue variation, density variation, wind phase and brightness.
- Wind is a low-amplitude vertex offset weighted toward the upper canopy.
- Snow is biased toward upward-facing bent normals.
- Canopy shadow casting is disabled for the high-card batches; the existing single batched soft contact-shadow pass remains in place.

## Seasonal controls
The `StylizedFoliageSystem` exposes `set_season(season_index, duration)`:
- 0: spring
- 1: summer
- 2: autumn
- 3: winter

The child `SeasonManager` can also be accessed for signals. Seasonal transitions tween the shared shader parameters and activate a small CPUParticles3D leaf emitter per visible foliage chunk. Winter reduces canopy density and applies a restrained upward-facing snow tint. This first implementation is a stylized density transition, not a physically simulated leaf-by-leaf mesh rebuild.

## Lighting baseline
The world keeps its existing climate-aware ProceduralSky, sky ambient energy, filmic tonemapping, fog and warm coastal directional fill. The foliage shader adds only a restrained back-light term; it does not add a per-tree light or reflection probe. Compatibility-safe contact AO remains in the existing batched shadow pass.

## Validation
`tests/foliage_system_smoke.gd` checks chunk partitioning, all three LOD instance counts, shader features and the season transition. `VisualPresentationSmoke` asserts the new system is connected to the live world. The Godot validation workflow runs both tests.

Headless tests verify geometry/resource construction and source contracts. They do not substitute for the required real WebGL captures and physical Android review at close, medium and overview distances.
