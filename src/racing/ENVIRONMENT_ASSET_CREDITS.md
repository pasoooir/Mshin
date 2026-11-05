# Racing environment surface provenance

The racing renderer creates eight 256×256 RGBA8 surface maps locally from
original procedural algorithms. No remote image, texture CDN, or third-party
asset is requested for the track, terrain, buildings, or vegetation.

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

Three.js 0.180.0 is stored under `vendor/three/` from the official npm
distribution and is distributed under the MIT License. See
`vendor/three/LICENSE`. The renderer and add-on modules are served from this
repository and included in the service-worker app-shell cache.
