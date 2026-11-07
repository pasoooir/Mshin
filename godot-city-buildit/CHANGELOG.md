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
