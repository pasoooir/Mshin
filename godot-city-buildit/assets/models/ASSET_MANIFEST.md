# Mshin local building models

All four GLTF files in this directory are original procedural architectural meshes authored for Pasoo City BuildIt. They are self-contained (embedded geometry buffers; no external textures, URLs, or runtime downloads) and dedicated to **CC0 1.0**. No third-party model files are included.

| Model | Runtime path | Declared dimensions (m) | Use |
|---|---|---:|---|
| Villa house | `residential/villa_house.gltf` | 3.715 × 4.205 × 5.91 | Residential villa and legacy small house |
| Apartment tower | `residential/apartment_tower.gltf` | 3.5 × 4.15 × 18.175 | Apartment residential |
| Neighborhood shop | `commercial/neighborhood_shop.gltf` | 3.5 × 4.04 × 5.2 | Generic commercial building visual |
| Small factory | `industrial/small_factory.gltf` | 3.5 × 3.53 × 7.68 | Generic industrial building visual |

Materials use glTF 2.0 metallic-roughness PBR factors plus embedded procedural PNG texture maps for Base Color, tangent-space Normal and Metallic-Roughness. The texture maps are generated patterns, not photographic scans or high-resolution photogrammetry textures. Their geometry includes facade openings/frames, glass, entry features, roof structures, balconies, signage, loading door and industrial equipment details as appropriate.

## Validation

The Godot GameplaySmoke test loads each local model through `BuildingModelLoader`, instantiates the imported PackedScene, and checks that it contains MeshInstance3D nodes. CI Import/Parse also validates Godot's glTF importer. These checks do not claim a real-device visual/performance review.

## License

CC0 1.0 Universal: https://creativecommons.org/publicdomain/zero/1.0/
