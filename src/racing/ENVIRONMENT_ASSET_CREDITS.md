# Racing environment surface provenance

The racing renderer creates its eight 256×256 RGBA8 surface maps locally from
original procedural algorithms at runtime. No remote image, texture CDN, or
third-party asset is requested for track, terrain, buildings, or vegetation.

| Surface role | Local surface key | Source | License |
| --- | --- | --- | --- |
| Track asphalt | `asphalt` | Original procedural RGBA8 generator | Project original work |
| Grass / green terrain | `grass` | Original procedural RGBA8 generator | Project original work |
| Desert terrain | `sand` | Original procedural RGBA8 generator | Project original work |
| Snow terrain | `snow` | Original procedural RGBA8 generator | Project original work |
| Rocky / mountain terrain | `rock` | Original procedural RGBA8 generator | Project original work |
| Building / pit surfaces | `concrete` | Original procedural RGBA8 generator | Project original work |
| Tree bark | `bark` | Original procedural RGBA8 generator | Project original work |
| Tree foliage | `foliage` | Original procedural RGBA8 generator | Project original work |

Three.js is vendored locally under `vendor/three/` from the official 0.180.0
distribution and is distributed under the MIT License. See
`vendor/three/LICENSE`. Runtime modules are served by this GitHub repository
and are included in the service-worker app-shell cache.
