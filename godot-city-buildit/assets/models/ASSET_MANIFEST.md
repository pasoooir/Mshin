# Mshin local building models

All five GLTF files in this directory are original procedural architectural meshes authored for Pasoo City BuildIt. They are self-contained (embedded geometry buffers; no external textures, URLs, or runtime downloads) and dedicated to **CC0 1.0**. No third-party model files are included.

| Model | Runtime path | Declared dimensions (m) | Use |
|---|---|---:|---|
| Villa house | `residential/villa_house.gltf` | 3.715 × 4.205 × 5.91 | `residential_villa` and legacy `residential_1` only; level-one starter hero remains procedural |
| Apartment mid-rise | `residential/apartment_tower.gltf` | 3.5 × 4.15 × 18.175 | `residential_apartment` and legacy `residential_2` only |
| Residential tower | `residential/residential_tower_75m.gltf` | 3.5 × 4.15 × 74.575 | Prepared asset; not assigned until large building footprints are supported |
| Neighborhood shop | `commercial/neighborhood_shop.gltf` | 3.5 × 4.04 × 5.2 | `shop_chain` archetype only; other shops keep their own type-specific procedural architecture |
| Small factory | `industrial/small_factory.gltf` | 3.5 × 3.53 × 7.68 | `factory_small` and legacy `industrial_1` only; larger factory tiers keep distinct procedural facilities |

Materials use glTF 2.0 metallic-roughness PBR factors plus embedded procedural PNG texture maps for Base Color, tangent-space Normal and Metallic-Roughness. The texture maps are generated patterns, not photographic scans or high-resolution photogrammetry textures. Their geometry includes facade openings/frames, glass, entry features, roof structures, balconies, signage, loading door and industrial equipment details as appropriate.

| Traditional restaurant | `commercial/restaurant_traditional.tscn` | 3.4 × 3.4 plot target | `restaurant_traditional`; bespoke warm masonry, pitched roof, dining terrace and kitchen flue |
| Fast-food outlet | `commercial/fast_food.tscn` | 3.4 × 3.4 plot target | `fast_food`; low modern volume, glazed counter, branded canopy and drive-through marker |
| Hardware store | `commercial/hardware_store.tscn` | 3.4 × 3.4 plot target | `hardware_store`; warehouse roof, loading shutter, lumber racks and steel display frames |
| Farmers market | `commercial/farmers_market.tscn` | 3.4 × 3.4 plot target | `farmers_market`; open pavilion, timber posts, stall counters, awnings and produce crates |
| Furniture store | `commercial/furniture_store.tscn` | 3.4 × 3.4 plot target | `furniture_store`; glazed showroom, interior furniture displays and delivery dock |

These five authored scene assets are original local Godot 3D scenes driven by `scripts/buildings/BuildingAssetModel.gd`; their mesh geometry and PBR materials are created from local primitives and the shared surface library. They are separate exact-type scene assets, not GLTF binaries. Their scene/import/runtime and camera-scale checks are covered by GameplaySmoke; visual review on physical mobile hardware remains separate.

## Procedural building surface library

The procedural building mesh path also uses `scripts/buildings/BuildingSurfaceLibrary.gd`. It creates and caches local 128×128 maps for Base Color, tangent-space Normal, Roughness and Metallic. Surface families include plaster, brick courses, timber grain, reflective glass, brushed metal, roof tiles and concrete aggregate. The window helpers explicitly request glass and painted-metal frame profiles; the library is deterministic and has no CDN/runtime dependency.

These generated maps are procedural texture patterns, not photographic scans or third-party texture downloads. They improve material response and visual breakup, but they do not count as high-resolution photogrammetry textures or as a replacement for the dedicated per-building GLTF models still listed in the asset matrix.

## Validation

`BuildManager.BUILDING_MODEL_REGISTRY` assigns each available GLTF to exact building type IDs; it does not infer a model from a broad category. The Godot GameplaySmoke test loads each local model through `BuildingModelLoader`, instantiates the imported PackedScene, checks renderable MeshInstance3D surfaces, and verifies that unrelated commercial/factory types do not inherit generic GLTF paths. CI Import/Parse also validates Godot's glTF importer. These checks do not claim a real-device visual/performance review.

## License

CC0 1.0 Universal: https://creativecommons.org/publicdomain/zero/1.0/
