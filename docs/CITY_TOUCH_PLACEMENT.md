# Native city touch placement

## Component setup

Attach `MshinCityPlacementController` to a scene controller. Assign the scene camera, building prefab, city placement root and (recommended) `MshinCityOrbitCamera`. The orbit controller is automatically paused during placement and restored on cancellation or commit.

Call `beginPlacement()` from the build-menu action. Drag to position the preview on the ground plane and release to commit. Call `cancelPlacement()` to discard the preview.

## Placement validation

- Screen coordinates are projected through the assigned camera onto a horizontal world plane.
- Optional grid snapping is controlled by `gridSize`.
- Active children of the placement root reserve their grid cells; occupied positions cannot be previewed or committed.
- When grid snapping is disabled, `occupancyTolerance` prevents near-overlapping placements.
- Parallel, behind-camera and out-of-range rays are rejected.
- Touch cancellation never commits a building.
- Orbit gestures are paused while placement mode owns touch movement.

## Scope boundary

This is still a placement foundation. Zoning, road adjacency, economy/currency transactions, building limits, persistent save data, translucent ghost materials, construction scaffold visuals and scene/prefab wiring remain outstanding. Cocos Creator Editor import, APK build and Android device verification are not yet evidenced.

## Acceptance checks

1. Missing camera, prefab or root prevents placement.
2. Preview follows valid ground-plane touch positions and snaps deterministically.
3. Occupied cells and near-overlapping unsnapped positions are rejected.
4. Invalid rays cannot commit.
5. Placement mode pauses orbit gestures; cancel/commit restores orbit.
6. A valid release creates exactly one building and starts progression.
7. Touch cancel and explicit cancel never commit.
8. Disabling the component unregisters all global touch listeners.
