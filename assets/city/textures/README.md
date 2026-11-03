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
The rasterizer writes PNGs to `assets/city/textures/generated/`. The existing GitHub Actions workflow `Validate and rasterize city texture sources` verifies that all six expected outputs are valid 512×512 PNGs and uploads them as the `mshin-city-textures-512` artifact for 14 days. On pushes to `main` and manual workflow dispatch, a separate job copies the validated PNGs into `assets/resources/city/textures/generated/` and commits them when changed. PR runs validate and publish an artifact but do not commit runtime assets. Import/configure the textures in Cocos Creator 3.8.6 materials separately; the SVGs remain editable source masters.

## Quality boundary
These are first-pass procedural albedo patterns. They do not yet include normal/roughness maps, UV validation, mipmap inspection, or Android GPU profiling. Do not mark final PBR material acceptance complete until those checks pass.
