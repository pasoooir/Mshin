# Racing environment surface assets

The race renderer streams the following 1K diffuse maps directly from the official Poly Haven asset CDN. The original source assets are released under CC0 1.0; the game keeps its procedural fallback colors if a remote request is blocked or unavailable.

| Surface role | Asset | Official source | CDN path |
|---|---|---|---|
| Track asphalt | Asphalt 03 | https://polyhaven.com/a/asphalt_03 | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/asphalt_03/asphalt_03_diff_1k.jpg |
| Grass / green terrain | Grass Ground | https://polyhaven.com/a/grass_ground | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/grass_ground/grass_ground_diff_1k.jpg |
| Desert terrain | Sand 01 | https://polyhaven.com/a/sand_01 | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/sand_01/sand_01_diff_1k.jpg |
| Snow terrain | Snow 03 | https://polyhaven.com/a/snow_03 | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/snow_03/snow_03_diff_1k.jpg |
| Rocky / mountain terrain | Rocky Terrain 02 | https://polyhaven.com/a/rocky_terrain_02 | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rocky_terrain_02/rocky_terrain_02_diff_1k.jpg |
| Building / pit surfaces | Concrete Floor 02 | https://polyhaven.com/a/concrete_floor_02 | https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/concrete_floor_02/concrete_floor_02_diff_1k.jpg |

Textures are loaded asynchronously with CORS enabled, mipmaps and repeat wrapping. A 1×1 fallback texture is created immediately, so a slow CDN never blocks the first frame or prevents the race from starting. Texture sampling is world-space in the shared WebGL PBR shader; road, terrain, hills and selected built surfaces receive scanned detail while retaining each biome's palette.
