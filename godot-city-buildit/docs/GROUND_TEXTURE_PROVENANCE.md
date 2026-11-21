# Ground Texture Provenance

The world renderer can use these seamless CC0 base-colour textures when the CDN is reachable. Procedural textures remain in place as an offline fallback; gameplay and scene startup must not depend on a successful network request.

| Surface | Asset | Source |
|---|---|---|
| Meadow grass | Wild Meadow Grass 2K | https://cdn.meshy.ai/landing-assets/textures/grass/wild-meadow-grass/wild-meadow-grass-2k.jpg |
| Sandy ground | Pitted Sandy Ground 2K | https://cdn.meshy.ai/landing-assets/textures/grass/pitted-sandy-ground/pitted-sandy-ground-2k.jpg |
| All asphalt | Dark Asphalt 2K | https://cdn.meshy.ai/landing-assets/textures/stone/dark-asphalt/dark-asphalt-2k.jpg |

The source library identifies these assets as seamless, CC0, and suitable for commercial use. The downloaded/served image is only the base-colour map in this first integration; the renderer retains its procedural normal map for asphalt. Do not introduce debris/vegetation on road surfaces. Environmental scatter must exclude occupied road cells.
