# Ground Texture Provenance

The playable world uses CC0 texture previews served from the Poly Haven CDN. The CDN images are optional visual enhancements: procedural grass, sand and asphalt textures remain available as offline fallbacks, so the city can start without network access.

| Surface | Asset | License | CDN source |
|---|---|---|---|
| Meadow grass | [Leafy Grass](https://polyhaven.com/a/leafy_grass) | CC0 | https://cdn.polyhaven.com/asset_img/primary/leafy_grass.png?height=512&quality=95&v=8866acdc |
| Coastal sand | [Coast Sand 02](https://polyhaven.com/a/coast_sand_02) | CC0 | https://cdn.polyhaven.com/asset_img/primary/coast_sand_02.png?height=512&quality=95&v=7b305d92 |
| All asphalt (highway, connector and city roads) | [Clean Asphalt](https://polyhaven.com/a/clean_asphalt) | CC0 | https://cdn.polyhaven.com/asset_img/primary/clean_asphalt.png?height=512&quality=95&v=547f00f6 |

The CDN supplies the base-colour imagery. Local procedural normal detail remains the fallback for asphalt. The highway, city connector and city streets use the same Clean Asphalt source; no gravel, twigs, stones or vegetation are intentionally placed on asphalt. Environmental scatter must exclude occupied road cells.

Asset source pages identify these materials as CC0. The game must retain its procedural fallback if a CDN request fails or the player is offline.
