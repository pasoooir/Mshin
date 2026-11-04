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

## Original SimCity-style object direction

Mshin uses an original, friendly miniature-city visual language inspired by the readability and colorful architectural variety of mobile city builders. It does not copy SimCity BuildIt proprietary meshes, textures, logos, or UI.

The runtime Three.js renderer builds the current city structures as real 3D geometry. Its authored object families include detached homes, shops, light industry, civic buildings, parks, police/fire/health/education facilities, and utility buildings. Building facades now carry window detail on all four elevations so the structures remain visually authored during a full 360-degree orbit. Roofline trim, chimneys, rooftop equipment, storefront glazing, service-color markers, and small environmental props provide silhouette and scale cues.

See `scene-object-catalog.json` for the object-family inventory and acceptance gates. The initial city save remains empty; this catalog changes rendering only and does not seed buildings into the city.
