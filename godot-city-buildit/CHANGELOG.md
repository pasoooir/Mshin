# Changelog

## 0.6.0
- Fixed the undefined commercial building selection by wiring the commercial HUD action to `building_supplies`.
- Added full rectangular footprint occupancy checks for multi-cell buildings.
- Required every building to have edge-adjacent road access; road tiles cannot overlap buildings.
- Fixed touch/mouse drag gestures so a pan or pinch does not trigger placement on release.
- Added local power/water coverage and capacity accounting with a happiness impact.
- Completed the first playable progression: road → house/factory/shop → metal production and collection → Nails crafting → house upgrade → population/XP.
- Stabilized camera pan/pinch and green/red placement preview.
- Added static resource-path validation.

## 1.0.0
- Fixed the camera's initial transform so the view starts above the terrain and looks at the city pivot.
- Added connected-road validation, world bounds and clearer road markings.
- Reworked the mobile toolbar into a landscape bottom dock and corrected the default orientation to landscape.
- Added local city save/load, 30-second autosave and a manual save button.
- Corrected power/water allocation so each home is served only when both nearby coverage and available capacity exist.
- Added an automated end-to-end gameplay smoke test for road access, footprint overlap, construction, factory production, material collection, crafting, utilities, house upgrade, population and save.
