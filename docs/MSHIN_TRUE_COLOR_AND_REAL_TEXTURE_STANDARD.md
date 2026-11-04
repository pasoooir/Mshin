# Mshin — True-colour and real-world material standard

## Colour precision

- Display/output target: 24-bit RGB (8 bits per channel), 16,777,216 possible sRGB values.
- Authoring and texture colour space: sRGB.
- Lighting and interpolation: linear-sRGB / linear-light calculations.
- Display transform: renderer-managed tone mapping followed by sRGB output conversion.
- HDR lighting is a separate dynamic-range feature; it does not replace the 24-bit display target.
- Never quantize the sky, foliage, ground, architecture or material tint to a short palette.

## Atmosphere

The sky is evaluated continuously from the simulation's minute-of-day and sampled from a multi-stop natural atmospheric curve: deep night, pre-dawn blue, violet/pink dawn, warm sunrise, clear daytime blue, golden hour, orange/pink sunset, violet twilight and night. Values are interpolated in linear light and encoded back to 24-bit sRGB. Seasonal and weather tints are blended without abrupt palette switching.

The visible sky should be a vertical zenith-to-horizon gradient with a physically plausible sun glow, not a single flat blue fill. Fog colour follows the horizon colour. Weather changes atmospheric scattering, contrast and colour temperature.

## Surface and texture standard

Use PBR maps where they add visible value:
- Base colour/albedo (sRGB)
- Normal (linear data)
- Roughness (linear data)
- Metallic (linear data, usually zero for stone, plaster, soil and vegetation)
- Ambient occlusion (linear data, where baked AO is appropriate)

Prioritize licensed real-world photographic scans from Poly Haven and ambientCG. Retain source URL, asset ID, licence, author and attribution requirements in the asset manifest. Never claim a procedural noise texture is a photographic scan. Procedural tileable textures are acceptable as a fallback and for variation layers, not as a false substitute for photo-sourced materials.

Use 2K–4K source textures for close-up hero buildings where memory allows; generate mipmaps and KTX2/Basis runtime variants. Mobile quality tiers may select 512/1K/2K variants according to GPU budget. Avoid loading all high-resolution maps at once.

## Visual acceptance

- Capture sky at dawn, noon, golden hour, sunset and midnight.
- Confirm a smooth gradient from zenith to horizon.
- Verify rain, snow, heat and seasonal tint effects.
- Verify no neon foliage or uniformly saturated artificial surfaces.
- Inspect close-up material tiling, texel density, normal direction and roughness response.
- Verify 24-bit output and no visible banding under supported browser/display output.
