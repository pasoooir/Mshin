# City GLTF asset pipeline

Original, self-contained glTF 2.0 building assets for Mshin.

- `manifest.json` is the inventory; all paths are same-origin relative for GitHub Pages and offline caching.
- Models contain embedded binary geometry, indexed triangles, vertex normals and PBR material factors.
- Coordinate system: right-handed, Y-up; dimensions in meters; origin at footprint center on ground.
- Assets are original procedural meshes authored for Mshin and declared CC0-1.0. No third-party models or textures are redistributed.
- No remote buffers, textures or model URLs are allowed. New third-party assets require verified redistribution rights and provenance.
- LODs and texture maps are not yet authored; this slice establishes the contract and distinct architecture silhouettes.

| Type | Features | Dimensions (m) |
|---|---|---|
| House | Gabled terracotta roof, entrance, windows | 2.45 × 2.55 × 2.05 |
| Apartment | Four balcony/window bands, flat roof | 2.45 × 3.95 × 2.08 |
| Shop | Glazed storefront, striped awning | 2.65 × 2.10 × 2.72 |

## Runtime note

The model files and manifest are same-origin and precached by the service worker. Per-model `scale` values in the manifest align the GLTF dimensions with the procedural blockout footprints. The preview page currently imports the existing Three.js runtime through its CDN import map; therefore a first offline visit may show the built-in SVG fallback rather than the WebGL scene. The procedural building fallback also remains active if an individual GLTF request fails.
