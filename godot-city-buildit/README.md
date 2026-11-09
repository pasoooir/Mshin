# Pasoo City BuildIt

**Version 1.0.0 — Playable Godot project**

A self-contained, mobile-first 3D city-building game built with **Godot 4.3+**, GDScript and the GL Compatibility renderer (required for browser export). All gameplay code and generated visuals are local; the project does not need a network connection after import.

## Play in a browser

After the **Mshin Playable Web** GitHub Actions workflow succeeds, open [Play Mshin](https://pasoooir.github.io/Mshin/) on a phone or desktop browser. Tap **PLAY MSHIN**; the launcher opens the exported game and requests fullscreen and landscape orientation where the browser allows it. No Godot installation is required for players.

The web build is generated automatically from this Godot project and deployed to GitHub Pages. The first deployment may take a few minutes.

## Open and run in Godot

1. Download and install the **standard (non-.NET) Godot 4.3 or newer editor** from the [official Godot download archive](https://godotengine.org/download/archive/).
2. Open Godot Project Manager and choose **Import**.
3. Select this folder: `godot-city-buildit/project.godot`.
4. Wait for the first asset/script scan to finish.
5. Select the imported project and press **F6** to run the main scene or **F5** to run the project.

From a terminal at the repository root:

```bash
godot --path godot-city-buildit
```

Main scene: `res://scenes/main.tscn`.

## First city — complete gameplay loop

1. Tap the **road** icon and place a connected road chain. Each tile costs 50 Simoleons; after the first tile, each new tile must connect to the existing road network.
2. Tap **house** and place a house beside the road.
3. Tap **factory** and place a factory beside the road.
4. Tap **shop** and place a Building Supplies shop beside the road.
5. Wait for construction and factory production. Tap the factory when its green check appears to collect Metal.
6. Tap the Building Supplies shop to craft Nails from Metal.
7. Collect another Metal from the factory.
8. Tap the house when its yellow hard hat appears. The house upgrades, its population increases, and the city gains XP.

The first upgrade consumes **1 Nail + 1 Metal**. House progression has six stages. The initial city starts with 5,000 Simoleons so the complete starter loop, including two utilities, can be tested immediately.

## Visual foundation — Phase 0.1 first slice

The coastal environment uses local procedural assets only (no runtime downloads): multi-palette terrain vertex colors, instanced grass blades and varied tree crowns, a layered beach/shallow-water transition, animated blue/turquoise water shader, locally generated asphalt grain, raised curbs and sidewalks. Building facades include framed windows, doors, awnings, roof details, signs and industrial vents; construction completion uses a lightweight sparkle burst. Warm directional fill and atmospheric fog are configured for the GL Compatibility renderer.

This is the first visual-quality slice, not the final art target: production-quality GLB building families, richer road intersections/markings, stronger shoreline foam/reflections, mobile GPU profiling and a verified 60 FPS budget remain open.

## HUD and local icon assets

All visible catalog and HUD items use local transparent PNG-32 artwork from `assets/icons/<category>/<id>.png`. `scripts/ui/Icons.gd` is the single path/loading helper and falls back safely to `assets/icons/ui/placeholder.png`. Icons are 128×128 RGBA, alpha-transparent, locally generated, and filtered linearly for mobile UI. The icon validator scans building definitions, service/specialization groups, raw materials, crafted recipes, toolbar controls and status badges; missing files, non-RGBA PNGs, undersized art or opaque canvas corners fail CI. The artwork is original procedural artwork and uses no third-party icon pack or external runtime assets.
\n## City services

Wind power and water towers each provide 12 units of capacity within a 28 m coverage radius. Each completed home requires 2 power and 2 water. The HUD shows capacity used, and city happiness is calculated from homes receiving both services.

## Controls

- **Mobile:** landscape orientation; one-finger drag pans; two-finger pinch zooms and twist rotates the camera; short taps place or interact.
- **Desktop:** left-drag pans; mouse wheel zooms; left-click places or interacts.
- The placement preview is green on a valid plot and red on an invalid plot.
- The right-side vertical toolbar uses locally drawn vector icons (no emoji glyphs, external textures or CDN): roads, residential, commercial, industrial, services, specializations and bulldoze. Selecting a category opens a compact icon-only submenu. Storage, trade, save and cancel remain in the bottom action row. Specialization options beyond parks and destructive bulldozing are currently UI entry points; their full gameplay behavior is not yet implemented.
- The **save** icon writes the city immediately. The game also autosaves every 30 seconds and on window close.

## Validation and automated gameplay test

Run the static validator:

```bash
python tools/validate_project.py
```

Run the automated gameplay integration test with Godot:

```bash
godot --headless --path godot-city-buildit res://tests/gameplay_smoke.tscn
```

The integration test builds a connected road, checks building footprints and road access, completes construction, collects two Metal, crafts Nails, verifies power/water coverage, upgrades the house, checks population growth and writes a save file. GitHub Actions runs this test using Godot 4.3 on every relevant push and pull request.
