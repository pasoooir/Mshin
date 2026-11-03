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

## Import rule
SVG files are editable source masters, **not runtime Cocos textures**. Rasterize to PNG (minimum 256×256; 512×512 recommended for close views), then import the PNG into Cocos Creator 3.8.6 and configure repeat/wrap sampling in the material. Keep source SVG and generated PNG together so texture changes remain reproducible.

## Quality boundary
These are first-pass procedural albedo patterns. They do not yet include normal/roughness maps, UV validation, mipmap inspection, or Android GPU profiling. Do not mark final PBR material acceptance complete until those checks pass.
