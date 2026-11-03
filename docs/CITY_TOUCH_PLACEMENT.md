# Native city touch placement

## Component

`assets/scripts/CityPlacementController.ts` provides a first native touch-placement workflow for Cocos Creator 3.8.6.

1. Attach `MshinCityPlacementController` to a scene controller node.
2. Assign the scene Camera to `cityCamera`.
3. Assign a building Prefab to `buildingPrefab`.
4. Assign the city world root to `placementRoot`.
5. Call `beginPlacement()` from a build-menu button.
6. Drag to position the preview on the ground plane; release to place the building.
7. A placed building receives `CityBuildingProgression` and starts its configured construction timer.
8. Call `cancelPlacement()` to discard the preview.

## Placement behavior

- Screen coordinates are projected through the assigned camera onto a configurable horizontal world plane.
- Optional grid snapping is controlled by `gridSize`.
- Rays parallel to the ground plane and intersections outside the configured distance are rejected.
- Touch cancellation does not commit a building.

## Current limitations

This is a foundational placement flow, not the complete city build/economy system. It does not yet validate plot zoning, road adjacency, collisions, occupied cells, currency, building limits, persistent save data, a translucent shader ghost, or construction visuals. Those must be added before production gameplay. A real Cocos scene, prefab assets, Editor import, APK build and Android device verification are still outstanding.

## Acceptance checks

1. Missing camera, prefab or root prevents arming placement.
2. Preview follows valid ground-plane touch positions.
3. Grid snapping is deterministic.
4. Invalid/parallel/out-of-range rays cannot commit a building.
5. Touch release commits exactly one building and starts construction progression.
6. Touch cancellation and explicit cancellation never commit a building.
7. Disabling the component unregisters all global touch listeners.
