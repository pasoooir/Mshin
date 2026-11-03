# City procedural texture source library

This folder contains six original, seamless SVG texture masters authored procedurally for the native Cocos city visual slice. They are not copied from the supplied game screenshots.

## Assets
- grass.svg — mottled natural grass
- asphalt.svg — dark fine-grain road surface
- sidewalk.svg — repeating concrete paving slabs
- brick.svg — staggered masonry courses
- concrete.svg — subtle cast-concrete grain
- roof.svg — staggered roof-tile pattern
- texture-manifest.json — material intent and raster targets

## Reproducible rasterization
Install the open-source Python packages Pillow and CairoSVG, then run:
```sh
python -m pip install pillow cairosvg
python tools/rasterize-city-textures.py --size 512
```
The script writes PNGs to `assets/city/textures/generated/`. Import those PNGs into Cocos Creator 3.8.6; the SVGs remain editable source masters. Configure repeat/wrap sampling in the Cocos material.

## Quality boundary
These are first-pass procedural albedo patterns. They do not yet include normal/roughness maps, UV validation, mipmap inspection, or Android GPU profiling. Do not mark final PBR material acceptance complete until those checks pass.
