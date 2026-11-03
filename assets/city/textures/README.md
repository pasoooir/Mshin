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
python tools/validate-city-texture-raster.py
```
The rasterizer writes PNGs to `assets/city/textures/generated/`. The validator requires all six expected textures to decode as non-empty square PNGs at least 256 px wide. Import generated PNGs into Cocos Creator 3.8.6; the SVGs remain editable source masters.

The `Validate and package city textures` GitHub Actions workflow runs the rasterization/validation pipeline and publishes `mshin-city-textures-512` as a 30-day artifact. This proves file generation and integrity only; it does not import textures into Cocos automatically.

## Quality boundary
These are first-pass procedural albedo patterns. They do not yet include normal/roughness maps, UV validation, mipmap inspection, material wiring, or Android GPU profiling. Do not mark final PBR material acceptance complete until those checks pass.
