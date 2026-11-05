# Racing environment surface provenance

All eight 1K CC0 diffuse maps are committed in `assets/textures/` and loaded
from this GitHub Pages repository using same-origin URLs. There is no runtime
Poly Haven CDN fallback. A local procedural RGBA8 map is drawn immediately and
remains available if a local image cannot load or the WebGL context is restored.

| Surface role | Local file | Official source | License |
| --- | --- | --- | --- |
| Track asphalt | `asphalt_03_diff_1k.jpg` | https://polyhaven.com/a/asphalt_03 | CC0 1.0 |
| Grass / green terrain | `grass_ground_diff_1k.jpg` | https://polyhaven.com/a/grass_ground | CC0 1.0 |
| Desert terrain | `sand_01_diff_1k.jpg` | https://polyhaven.com/a/sand_01 | CC0 1.0 |
| Snow terrain | `snow_03_diff_1k.jpg` | https://polyhaven.com/a/snow_03 | CC0 1.0 |
| Rocky / mountain terrain | `rocky_terrain_02_diff_1k.jpg` | https://polyhaven.com/a/rocky_terrain_02 | CC0 1.0 |
| Building / pit surfaces | `concrete_floor_02_diff_1k.jpg` | https://polyhaven.com/a/concrete_floor_02 | CC0 1.0 |
| Tree bark | `bark_brown_02_diff_1k.jpg` | https://polyhaven.com/a/bark_brown_02 | CC0 1.0 |
| Tree foliage | `leafy_grass_diff_1k.jpg` | https://polyhaven.com/a/leafy_grass | CC0 1.0 |

The original Poly Haven license is available at https://polyhaven.com/license.
Three.js 0.180.0 is vendored under `vendor/three/` under the MIT License;
see `vendor/three/LICENSE`.
