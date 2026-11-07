# Pasoo City BuildIt

**Version 0.6.0**

A mobile-first 3D city-building prototype made with **Godot 4.3+**, GDScript and the Forward+ renderer.

## Run

1. Install Godot **4.3 or newer** (standard build, not .NET).
2. Open Godot Project Manager → **Import** → select this folder's `project.godot`.
3. Open the project and allow the initial import to finish.
4. Press **F5** to run the project.

Main scene: `res://scenes/main.tscn`. Game logic and art placeholders are local; no network access is required.

## Core gameplay

1. Tap the **road** icon and tap the ground to lay roads (50 Simoleons per tile).
2. Select **house** and place a house footprint next to a road.
3. Select **factory** and place a factory next to a road.
4. Wait for the factory timer, then tap the factory to collect Metal.
5. Place a **Building Supplies** shop next to a road. Collect Metal from the factory.
6. Cancel placement with **X**, tap the Building Supplies shop to craft Nails.
7. Tap the house when its yellow hard hat appears to upgrade it. Population and XP increase.

The first house upgrade consumes 1 Nail + 1 Metal. Later stages use the materials in `scripts/autoload/ProductionManager.gd`.

## Utilities

Power and water buildings provide capacity within a local coverage radius. Residential buildings consume 2 units of each utility when covered. The HUD displays used/capacity and city happiness reflects utility coverage.

## Controls

- Mobile: one-finger drag pans; two-finger pinch zooms; a short tap places/interacts.
- Desktop: left-drag pans; mouse wheel zooms; left-click places/interacts.
- Ghost preview is green for a valid plot and red for an invalid plot.
- Tap **X** to cancel active placement mode.

## Validation

Run `python tools/validate_project.py` for static resource-path and consistency checks. GitHub Actions runs this validator and a Godot 4.3 headless project parse.
