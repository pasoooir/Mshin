# Racing environment surface assets

The renderer prefers repository-local, photoscanned diffuse maps from Poly Haven and falls back to the same official CC0 source URLs only when a local file is absent. All assets listed below are free for commercial and personal use under CC0 1.0.

Download the eight real 1K maps into `assets/textures/` with:

```sh
npm run assets:race-textures
```

| Surface role | Asset | Local file | Official source |
|---|---|---|---|
| Track asphalt | Asphalt 03 | `asphalt_03_diff_1k.jpg` | https://polyhaven.com/a/asphalt_03 |
| Grass / green terrain | Grass Ground | `grass_ground_diff_1k.jpg` | https://polyhaven.com/a/grass_ground |
| Desert terrain | Sand 01 | `sand_01_diff_1k.jpg` | https://polyhaven.com/a/sand_01 |
| Snow terrain | Snow 03 | `snow_03_diff_1k.jpg` | https://polyhaven.com/a/snow_03 |
| Rocky / mountain terrain | Rocky Terrain 02 | `rocky_terrain_02_diff_1k.jpg` | https://polyhaven.com/a/rocky_terrain_02 |
| Building / pit surfaces | Concrete Floor 02 | `concrete_floor_02_diff_1k.jpg` | https://polyhaven.com/a/concrete_floor_02 |
| Tree bark | Bark Brown 02 | `bark_brown_02_diff_1k.jpg` | https://polyhaven.com/a/bark_brown_02 |
| Tree foliage | Leafy Grass | `leafy_grass_diff_1k.jpg` | https://polyhaven.com/a/leafy_grass |

The downloaded files are actual Poly Haven photographs, not generated/procedural color maps. The renderer creates an immediate procedural safety fallback, prefers local files, then tries the official CDN if the local file is missing. Software-renderer and data-saver sessions continue to skip texture uploads to protect mobile performance.

Poly Haven licensing: https://polyhaven.com/license
