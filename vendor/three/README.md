# Vendored Three.js runtime

- Package: `three`
- Version: `0.180.0` (r180)
- Upstream project: https://github.com/mrdoob/three.js
- Upstream release commit: `0af9729d0c143a86a1d725d6e2c3ad83301f3f34`
- License: MIT; see `LICENSE`.

The runtime files are committed here so GitHub Pages and the service worker can
serve them from the same origin. The browser does not need jsDelivr, unpkg, or
another third-party host to load Three.js or the included add-ons.

Included modules:
- `build/three.module.min.js`
- `build/three.core.min.js`
- `examples/jsm/controls/OrbitControls.js`
- `examples/jsm/loaders/GLTFLoader.js`
- `examples/jsm/utils/BufferGeometryUtils.js`

The module build imports its paired `three.core.min.js`; keep the two files
from the same exact Three.js release.
