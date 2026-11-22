# Coastal World Rendering and Asset Policy

## Goal
Build a readable, natural coastal starter region in the Godot 4.3 GL Compatibility renderer. The far overview must show, in one frame, the playable starter city, rolling vegetated land, a broad pale-sand beach, a shallow turquoise shelf, surf/foam, and deep Pacific water. The scene must not collapse into a featureless green field at the maximum supported zoom.

## Rendering implementation
- Terrain, beach, shallow water, offshore water, waves, shoreline foam, and vegetation are generated locally by Godot scripts and shaders.
- The ocean is a continuous broad mesh, not a narrow decorative strip.
- Water uses separate nearshore and offshore materials with depth-based colour, animated multi-scale waves, analytic surface normals, highlights, and a Fresnel contribution.
- The beach uses a continuous terrain material transition, wet-sand band, irregular shoreline, and broken foam.
- Camera framing is part of visual acceptance: city and coast must remain visible together at the maximum supported zoom.
- Keep draw calls and shadow casters bounded for mobile hardware.

## Offline and provenance policy
- No runtime CDN, remote HTTP request, remote font, remote shader, or external asset URL is permitted in the playable scene.
- Any third-party asset that is adopted must first be downloaded, checked for its exact licence and attribution requirements, then committed under `godot-city-buildit/assets/` with a provenance record containing source URL, author, licence, retrieval date, and local path.
- Prefer CC0 or permissive assets with clear redistribution rights. Do not copy assets whose licence is unclear or prohibits redistribution.
- Once vendored, runtime loading must use `res://` paths only. CI must fail if the world presentation introduces runtime CDN/HTTP dependencies.

## Visual acceptance gate
A successful headless test or successful Web export is not sufficient. The actual exported Web build must be opened in Chromium and produce saved desktop and mobile screenshots at:
1. opening overview,
2. maximum zoom-out,
3. medium coastal inspection,
4. close beach/water inspection.

The maximum-zoom screenshot must visibly contain all of: city/road context, land vegetation, continuous sand, shallow turquoise water, a broken surf line, and broad deep-blue sea. If any major band is missing, the visual milestone remains incomplete and must not be merged or deployed.

## Current implementation baseline
The first rebuild pass broadens the Pacific water mesh, adds a wider shallow-water shelf, makes both water surfaces double-sided for GL Compatibility robustness, improves wave shading and water optics, widens the sand transition, and points the opening camera across the city toward the coast. These changes require visual review of the newly captured Web screenshots before the milestone can be accepted.
